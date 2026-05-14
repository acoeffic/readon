-- Fix : get_people_you_may_know et get_suggested_readers référencent une table
-- "reading_flows" qui n'existe pas dans cette DB. Le calcul du flow est fait
-- côté Dart depuis reading_sessions (cf. flow_service.dart). On remplace le
-- sous-select par une constante 0 pour débloquer les RPC. Si on veut un vrai
-- current_flow plus tard, il faudra implémenter le calcul SQL-side ou créer
-- la table reading_flows.

-- ── 1. get_people_you_may_know ──────────────────────────────────────────

DROP FUNCTION IF EXISTS get_people_you_may_know(INTEGER) CASCADE;

CREATE OR REPLACE FUNCTION get_people_you_may_know(p_limit INTEGER DEFAULT 15)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  reading_habit TEXT,
  books_finished INTEGER,
  current_flow INTEGER,
  current_book_title TEXT,
  current_book_cover TEXT,
  score INTEGER,
  mutual_friends_count INTEGER,
  common_books_count INTEGER,
  common_groups_count INTEGER,
  common_genres_count INTEGER,
  reasons JSONB,
  mutual_avatars JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH
  caller_friends AS (
    SELECT CASE WHEN requester_id = v_caller THEN addressee_id
                ELSE requester_id END AS friend_id
    FROM friends
    WHERE status = 'accepted'
      AND (requester_id = v_caller OR addressee_id = v_caller)
  ),
  caller_excluded AS (
    SELECT CASE WHEN requester_id = v_caller THEN addressee_id
                ELSE requester_id END AS uid
    FROM friends
    WHERE status IN ('accepted', 'pending')
      AND (requester_id = v_caller OR addressee_id = v_caller)
  ),
  caller_books AS (
    SELECT DISTINCT ub.book_id
    FROM user_books ub
    WHERE ub.user_id = v_caller AND ub.status = 'finished'
  ),
  caller_groups AS (
    SELECT gm.group_id
    FROM group_members gm
    WHERE gm.user_id = v_caller
  ),
  caller_top_genres AS (
    SELECT b.genre, COUNT(*)::INTEGER AS n
    FROM user_books ub
    JOIN books b ON b.id = ub.book_id
    WHERE ub.user_id = v_caller
      AND ub.status = 'finished'
      AND b.genre IS NOT NULL
    GROUP BY b.genre
    ORDER BY n DESC
    LIMIT 3
  ),

  cand_via_friends AS (
    SELECT DISTINCT
      CASE WHEN f.requester_id = cf.friend_id THEN f.addressee_id
           ELSE f.requester_id END AS uid
    FROM caller_friends cf
    JOIN friends f
      ON (f.requester_id = cf.friend_id OR f.addressee_id = cf.friend_id)
     AND f.status = 'accepted'
  ),
  cand_via_books AS (
    SELECT DISTINCT ub.user_id AS uid
    FROM user_books ub
    WHERE ub.status = 'finished'
      AND ub.book_id IN (SELECT book_id FROM caller_books)
  ),
  cand_via_groups AS (
    SELECT DISTINCT gm.user_id AS uid
    FROM group_members gm
    WHERE gm.group_id IN (SELECT group_id FROM caller_groups)
  ),
  all_candidates AS (
    SELECT uid FROM cand_via_friends
    UNION
    SELECT uid FROM cand_via_books
    UNION
    SELECT uid FROM cand_via_groups
  ),
  filtered_candidates AS (
    SELECT ac.uid
    FROM all_candidates ac
    JOIN profiles p ON p.id = ac.uid
    WHERE ac.uid != v_caller
      AND ac.uid NOT IN (SELECT uid FROM caller_excluded)
      AND COALESCE(p.is_profile_private, FALSE) = FALSE
  ),

  signals AS (
    SELECT
      fc.uid,
      COALESCE((
        SELECT COUNT(*)::INTEGER
        FROM friends f
        WHERE (f.requester_id = fc.uid OR f.addressee_id = fc.uid)
          AND f.status = 'accepted'
          AND (CASE WHEN f.requester_id = fc.uid THEN f.addressee_id
                    ELSE f.requester_id END) IN (SELECT friend_id FROM caller_friends)
      ), 0) AS mutual_friends,
      COALESCE((
        SELECT COUNT(*)::INTEGER
        FROM user_books ub
        WHERE ub.user_id = fc.uid
          AND ub.status = 'finished'
          AND ub.book_id IN (SELECT book_id FROM caller_books)
      ), 0) AS common_books,
      COALESCE((
        SELECT COUNT(*)::INTEGER
        FROM group_members gm
        WHERE gm.user_id = fc.uid
          AND gm.group_id IN (SELECT group_id FROM caller_groups)
      ), 0) AS common_groups,
      COALESCE((
        SELECT COUNT(DISTINCT b.genre)::INTEGER
        FROM user_books ub
        JOIN books b ON b.id = ub.book_id
        WHERE ub.user_id = fc.uid
          AND ub.status = 'finished'
          AND b.genre IN (SELECT genre FROM caller_top_genres)
      ), 0) AS common_genres
    FROM filtered_candidates fc
  ),
  scored AS (
    SELECT
      s.uid,
      s.mutual_friends,
      s.common_books,
      s.common_groups,
      s.common_genres,
      (s.mutual_friends * 4
        + LEAST(s.common_books, 20) * 3
        + s.common_groups * 2
        + s.common_genres * 2) AS score
    FROM signals s
    WHERE s.mutual_friends > 0
       OR s.common_books >= 1
       OR s.common_groups > 0
       OR s.common_genres > 0
  ),

  enriched AS (
    SELECT
      sc.uid,
      p.display_name,
      p.avatar_url,
      p.reading_habit,
      sc.mutual_friends,
      sc.common_books,
      sc.common_groups,
      sc.common_genres,
      sc.score,
      COALESCE((
        SELECT COUNT(*)::INTEGER
        FROM user_books ub
        WHERE ub.user_id = sc.uid AND ub.status = 'finished'
      ), 0) AS books_finished,
      0::INTEGER AS current_flow,
      (
        SELECT b.title
        FROM user_books ub
        JOIN books b ON b.id = ub.book_id
        WHERE ub.user_id = sc.uid AND ub.status = 'reading'
        ORDER BY ub.updated_at DESC
        LIMIT 1
      ) AS current_book_title,
      (
        SELECT b.cover_url
        FROM user_books ub
        JOIN books b ON b.id = ub.book_id
        WHERE ub.user_id = sc.uid AND ub.status = 'reading'
        ORDER BY ub.updated_at DESC
        LIMIT 1
      ) AS current_book_cover,
      COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'id', mp.id,
          'display_name', mp.display_name,
          'avatar_url', mp.avatar_url
        ))
        FROM (
          SELECT p2.id, p2.display_name, p2.avatar_url
          FROM friends f
          JOIN profiles p2 ON p2.id = (CASE WHEN f.requester_id = sc.uid
                                            THEN f.addressee_id
                                            ELSE f.requester_id END)
          WHERE (f.requester_id = sc.uid OR f.addressee_id = sc.uid)
            AND f.status = 'accepted'
            AND (CASE WHEN f.requester_id = sc.uid THEN f.addressee_id
                      ELSE f.requester_id END) IN (SELECT friend_id FROM caller_friends)
          ORDER BY (p2.avatar_url IS NOT NULL) DESC, p2.display_name
          LIMIT 3
        ) mp
      ), '[]'::JSONB) AS mutual_avatars
    FROM scored sc
    JOIN profiles p ON p.id = sc.uid
  )

  SELECT
    e.uid AS user_id,
    e.display_name,
    e.avatar_url,
    e.reading_habit,
    e.books_finished,
    e.current_flow,
    e.current_book_title,
    e.current_book_cover,
    e.score,
    e.mutual_friends AS mutual_friends_count,
    e.common_books AS common_books_count,
    e.common_groups AS common_groups_count,
    e.common_genres AS common_genres_count,
    (
      SELECT COALESCE(jsonb_agg(r), '[]'::JSONB)
      FROM (
        SELECT jsonb_build_object('type', 'mutual_friends', 'count', e.mutual_friends) AS r
        WHERE e.mutual_friends > 0
        UNION ALL
        SELECT jsonb_build_object('type', 'common_books', 'count', e.common_books)
        WHERE e.common_books > 0
        UNION ALL
        SELECT jsonb_build_object('type', 'common_groups', 'count', e.common_groups)
        WHERE e.common_groups > 0
        UNION ALL
        SELECT jsonb_build_object('type', 'common_genres', 'count', e.common_genres)
        WHERE e.common_genres > 0
      ) reasons_sub
    ) AS reasons,
    e.mutual_avatars
  FROM enriched e
  ORDER BY e.score DESC, e.books_finished DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION get_people_you_may_know(INTEGER) TO authenticated;

-- ── 2. get_suggested_readers ────────────────────────────────────────────

DROP FUNCTION IF EXISTS get_suggested_readers(TEXT, INTEGER) CASCADE;

CREATE OR REPLACE FUNCTION get_suggested_readers(
  p_reading_habit TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 15
)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  books_finished BIGINT,
  current_flow INTEGER,
  current_book_title TEXT,
  current_book_cover TEXT,
  reading_habit TEXT,
  recent_sessions BIGINT,
  mutual_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  RETURN QUERY
  WITH caller_friends AS (
    SELECT CASE WHEN requester_id = v_caller THEN addressee_id
                ELSE requester_id END AS friend_id
    FROM friends
    WHERE status = 'accepted'
      AND v_caller IS NOT NULL
      AND (requester_id = v_caller OR addressee_id = v_caller)
  ),
  excluded_ids AS (
    SELECT CASE WHEN requester_id = v_caller THEN addressee_id
                ELSE requester_id END AS uid
    FROM friends
    WHERE v_caller IS NOT NULL
      AND (requester_id = v_caller OR addressee_id = v_caller)
      AND status IN ('accepted', 'pending')
  ),
  reader_stats AS (
    SELECT
      p.id AS uid,
      p.display_name,
      p.avatar_url,
      p.reading_habit,
      COALESCE((
        SELECT COUNT(*)
        FROM user_books ub
        WHERE ub.user_id = p.id AND ub.status = 'finished'
      ), 0) AS books_finished,
      0::INTEGER AS current_flow,
      (
        SELECT COUNT(*)
        FROM reading_sessions rs
        WHERE rs.user_id = p.id
          AND rs.end_time IS NOT NULL
          AND rs.created_at > NOW() - INTERVAL '14 days'
      ) AS recent_sessions,
      (
        SELECT b.title
        FROM user_books ub
        JOIN books b ON b.id = ub.book_id
        WHERE ub.user_id = p.id AND ub.status = 'reading'
        ORDER BY ub.updated_at DESC
        LIMIT 1
      ) AS current_book_title,
      (
        SELECT b.cover_url
        FROM user_books ub
        JOIN books b ON b.id = ub.book_id
        WHERE ub.user_id = p.id AND ub.status = 'reading'
        ORDER BY ub.updated_at DESC
        LIMIT 1
      ) AS current_book_cover,
      COALESCE((
        SELECT COUNT(*)::INTEGER
        FROM friends f2
        WHERE (f2.requester_id = p.id OR f2.addressee_id = p.id)
          AND f2.status = 'accepted'
          AND (CASE WHEN f2.requester_id = p.id THEN f2.addressee_id
                    ELSE f2.requester_id END) IN (SELECT friend_id FROM caller_friends)
      ), 0) AS mutual_count
    FROM profiles p
    WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
      AND p.id != COALESCE(v_caller, '00000000-0000-0000-0000-000000000000'::uuid)
      AND p.id NOT IN (SELECT uid FROM excluded_ids)
      AND EXISTS (
        SELECT 1 FROM reading_sessions rs
        WHERE rs.user_id = p.id AND rs.end_time IS NOT NULL
      )
      AND EXISTS (
        SELECT 1 FROM reading_sessions rs
        WHERE rs.user_id = p.id
          AND rs.end_time IS NOT NULL
          AND rs.created_at > NOW() - INTERVAL '14 days'
      )
  )
  SELECT
    rs.uid AS user_id,
    rs.display_name,
    rs.avatar_url,
    rs.books_finished,
    rs.current_flow,
    rs.current_book_title,
    rs.current_book_cover,
    rs.reading_habit,
    rs.recent_sessions,
    rs.mutual_count
  FROM reader_stats rs
  ORDER BY
    rs.mutual_count DESC,
    CASE WHEN p_reading_habit IS NOT NULL AND rs.reading_habit = p_reading_habit THEN 0 ELSE 1 END,
    rs.recent_sessions DESC,
    rs.books_finished DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_suggested_readers(TEXT, INTEGER) TO authenticated;

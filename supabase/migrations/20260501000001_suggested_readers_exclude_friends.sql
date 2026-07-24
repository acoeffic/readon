-- get_suggested_readers : exclure les amis existants (status accepted) et
-- les demandes en cours (status pending) pour qu'on ne propose pas des
-- profils déjà connectés. Boost mineur des profils ayant des amis communs.

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
    -- Exclure les amis acceptés et toute demande pending dans un sens ou l'autre
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
      COALESCE((
        SELECT current_flow
        FROM reading_flows rf
        WHERE rf.user_id = p.id
      ), 0) AS current_flow,
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
      -- Nombre d'amis communs : intersection caller_friends ∩ amis du candidat
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
    -- Prioriser les profils avec des amis en commun
    rs.mutual_count DESC,
    -- Puis le même reading_habit
    CASE WHEN p_reading_habit IS NOT NULL AND rs.reading_habit = p_reading_habit THEN 0 ELSE 1 END,
    -- Puis l'activité récente
    rs.recent_sessions DESC,
    -- Puis le nombre de livres
    rs.books_finished DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_suggested_readers(TEXT, INTEGER) TO authenticated;

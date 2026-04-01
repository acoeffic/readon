-- Migration : Exclure des statistiques les livres finis avec moins de 3 sessions
-- Un livre marque 'finished' ne compte dans les stats que s'il a >= 3 sessions completees.

-- =====================================================
-- 1. get_friend_profile_stats : ajouter filtre >= 3 sessions
-- =====================================================
CREATE OR REPLACE FUNCTION get_friend_profile_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_hide_hours BOOLEAN;
BEGIN
  -- Verify the caller is a friend (accepted status)
  IF NOT EXISTS (
    SELECT 1 FROM friends
    WHERE status = 'accepted'
    AND (
      (requester_id = auth.uid() AND addressee_id = p_user_id)
      OR (addressee_id = auth.uid() AND requester_id = p_user_id)
    )
  ) AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Not a friend';
  END IF;

  -- Verifier si l'utilisateur cible cache ses heures
  SELECT COALESCE(hide_reading_hours, FALSE)
  INTO v_hide_hours
  FROM profiles
  WHERE id = p_user_id;

  SELECT json_build_object(
    'books_finished', (
      SELECT COUNT(*) FROM user_books ub
      WHERE ub.user_id = p_user_id
        AND ub.status = 'finished'
        AND ub.is_hidden = FALSE
        AND (
          SELECT COUNT(*) FROM reading_sessions rs
          WHERE rs.book_id = ub.book_id::text
            AND rs.user_id = ub.user_id
            AND rs.end_time IS NOT NULL
        ) >= 3
    ),
    'total_pages', COALESCE((
      SELECT SUM(rs.end_page - rs.start_page)
      FROM reading_sessions rs
      LEFT JOIN user_books ub ON ub.user_id = rs.user_id AND ub.book_id::text = rs.book_id
      WHERE rs.user_id = p_user_id
        AND rs.end_page IS NOT NULL
        AND rs.start_page IS NOT NULL
        AND rs.end_time IS NOT NULL
        AND rs.is_hidden = FALSE
        AND COALESCE(ub.is_hidden, FALSE) = FALSE
    ), 0),
    'total_minutes', CASE
      WHEN v_hide_hours AND auth.uid() != p_user_id THEN NULL
      ELSE COALESCE((
        SELECT SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 60)
        FROM reading_sessions rs
        LEFT JOIN user_books ub ON ub.user_id = rs.user_id AND ub.book_id::text = rs.book_id
        WHERE rs.user_id = p_user_id
          AND rs.end_time IS NOT NULL
          AND rs.is_hidden = FALSE
          AND COALESCE(ub.is_hidden, FALSE) = FALSE
      ), 0)
    END
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;


-- =====================================================
-- 2. get_user_search_data : ajouter filtre >= 3 sessions
-- =====================================================
CREATE OR REPLACE FUNCTION get_user_search_data(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_is_private BOOLEAN;
  v_profile JSONB;
  v_badges JSONB;
  v_current_book JSONB;
  v_books_finished INT;
  v_friends_count INT;
  v_current_streak INT;
  v_current_user_id UUID;
  v_is_friend BOOLEAN;
BEGIN
  v_current_user_id := auth.uid();

  SELECT
    jsonb_build_object(
      'id', p.id,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url,
      'is_profile_private', COALESCE(p.is_profile_private, FALSE),
      'member_since', p.created_at
    )
  INTO v_profile
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  v_is_private := (v_profile->>'is_profile_private')::BOOLEAN;

  IF v_is_private THEN
    SELECT EXISTS (
      SELECT 1
      FROM friends
      WHERE ((requester_id = v_current_user_id AND addressee_id = p_user_id)
         OR (requester_id = p_user_id AND addressee_id = v_current_user_id))
        AND status = 'accepted'
    ) INTO v_is_friend;

    IF NOT v_is_friend OR v_current_user_id IS NULL THEN
      RETURN v_profile;
    END IF;
  END IF;

  -- Badges recents (3 plus recents debloques)
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', ub.badge_id,
      'name', b.name,
      'icon', b.icon,
      'color', b.color,
      'unlocked_at', ub.earned_at
    )
    ORDER BY ub.earned_at DESC
  )
  INTO v_badges
  FROM user_badges ub
  JOIN badges b ON b.id = ub.badge_id
  WHERE ub.user_id = p_user_id
  LIMIT 3;

  -- Livre actuellement en cours de lecture
  SELECT jsonb_build_object(
    'id', ub.id,
    'title', b.title,
    'author', b.author,
    'cover_url', b.cover_url
  )
  INTO v_current_book
  FROM user_books ub
  JOIN books b ON b.id = ub.book_id
  WHERE ub.user_id = p_user_id
    AND ub.status = 'reading'
  ORDER BY ub.updated_at DESC
  LIMIT 1;

  -- Nombre de livres termines (>= 3 sessions completees)
  SELECT COUNT(*)
  INTO v_books_finished
  FROM user_books ub
  WHERE ub.user_id = p_user_id
    AND ub.status = 'finished'
    AND (
      SELECT COUNT(*) FROM reading_sessions rs
      WHERE rs.book_id = ub.book_id::text
        AND rs.user_id = ub.user_id
        AND rs.end_time IS NOT NULL
    ) >= 3;

  -- Nombre d'amis acceptes
  SELECT COUNT(*)
  INTO v_friends_count
  FROM friends
  WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
    AND status = 'accepted';

  -- Streak actuel
  v_current_streak := 0;
  BEGIN
    SELECT get_current_streak_for_user(p_user_id) INTO v_current_streak;
  EXCEPTION
    WHEN undefined_function THEN
      SELECT COUNT(DISTINCT DATE(start_time))
      INTO v_current_streak
      FROM reading_sessions
      WHERE user_id = p_user_id
        AND end_time IS NOT NULL
        AND start_time >= CURRENT_DATE - INTERVAL '7 days';
  END;

  v_result := v_profile || jsonb_build_object(
    'recent_badges', COALESCE(v_badges, '[]'::JSONB),
    'current_book', v_current_book,
    'books_finished', v_books_finished,
    'friends_count', v_friends_count,
    'current_streak', COALESCE(v_current_streak, 0)
  );

  RETURN v_result;
END;
$$;


-- =====================================================
-- 3. get_reading_goals_progress : ajouter filtre >= 3 sessions
--    pour tous les goal types qui comptent des finished books
-- =====================================================
CREATE OR REPLACE FUNCTION get_reading_goals_progress(
  p_year INT DEFAULT EXTRACT(YEAR FROM NOW())::INT
)
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  SELECT json_agg(goal_data) INTO result
  FROM (
    SELECT
      g.id,
      g.category,
      g.goal_type,
      g.target_value,
      g.year,
      g.created_at,
      g.is_active,
      g.user_id,
      CASE
        WHEN g.goal_type = 'books_per_year' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND (
            SELECT COUNT(*) FROM reading_sessions rs
            WHERE rs.book_id = ub.book_id::text
              AND rs.user_id = ub.user_id
              AND rs.end_time IS NOT NULL
          ) >= 3
        )
        WHEN g.goal_type = 'nonfiction_books' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          JOIN books b ON b.id = ub.book_id
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND b.genre IS NOT NULL
          AND LOWER(b.genre) NOT IN (
            'fiction', 'roman', 'romance', 'science-fiction',
            'fantasy', 'thriller', 'horreur', 'policier',
            'manga', 'bande dessinee', 'comics'
          )
          AND (
            SELECT COUNT(*) FROM reading_sessions rs
            WHERE rs.book_id = ub.book_id::text
              AND rs.user_id = ub.user_id
              AND rs.end_time IS NOT NULL
          ) >= 3
        )
        WHEN g.goal_type = 'fiction_books' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          JOIN books b ON b.id = ub.book_id
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND b.genre IS NOT NULL
          AND LOWER(b.genre) IN (
            'fiction', 'roman', 'romance', 'science-fiction',
            'fantasy', 'thriller', 'horreur', 'policier',
            'manga', 'bande dessinee', 'comics'
          )
          AND (
            SELECT COUNT(*) FROM reading_sessions rs
            WHERE rs.book_id = ub.book_id::text
              AND rs.user_id = ub.user_id
              AND rs.end_time IS NOT NULL
          ) >= 3
        )
        WHEN g.goal_type = 'finish_started' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND (
            SELECT COUNT(*) FROM reading_sessions rs
            WHERE rs.book_id = ub.book_id::text
              AND rs.user_id = ub.user_id
              AND rs.end_time IS NOT NULL
          ) >= 3
        )
        WHEN g.goal_type = 'different_genres' THEN (
          SELECT COUNT(DISTINCT LOWER(b.genre))::INT FROM user_books ub
          JOIN books b ON b.id = ub.book_id
          WHERE ub.user_id = v_user_id
          AND ub.status = 'finished'
          AND EXTRACT(YEAR FROM ub.updated_at) = g.year
          AND b.genre IS NOT NULL
          AND (
            SELECT COUNT(*) FROM reading_sessions rs
            WHERE rs.book_id = ub.book_id::text
              AND rs.user_id = ub.user_id
              AND rs.end_time IS NOT NULL
          ) >= 3
        )
        WHEN g.goal_type = 'days_per_week' THEN (
          SELECT COUNT(DISTINCT DATE(rs.end_time))::INT
          FROM reading_sessions rs
          WHERE rs.user_id = v_user_id
          AND rs.end_time IS NOT NULL
          AND DATE(rs.end_time) >= date_trunc('week', CURRENT_DATE)::DATE
          AND DATE(rs.end_time) <= CURRENT_DATE
        )
        WHEN g.goal_type = 'streak_target' THEN 0
        WHEN g.goal_type = 'minutes_per_day' THEN (
          SELECT COALESCE(AVG(daily_minutes)::INT, 0)
          FROM (
            SELECT DATE(rs.end_time) AS read_date,
                   SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 60)::INT AS daily_minutes
            FROM reading_sessions rs
            WHERE rs.user_id = v_user_id
            AND rs.end_time IS NOT NULL
            AND DATE(rs.end_time) >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY DATE(rs.end_time)
          ) sub
        )
        ELSE 0
      END AS current_value,
      CASE
        WHEN g.goal_type = 'finish_started' THEN (
          SELECT COUNT(*)::INT FROM user_books ub
          WHERE ub.user_id = v_user_id
          AND ub.status IN ('reading', 'finished')
          AND EXTRACT(YEAR FROM ub.created_at) = g.year
        )
        ELSE NULL
      END AS extra_value
    FROM reading_goals g
    WHERE g.user_id = v_user_id
    AND g.is_active = TRUE
    AND g.year = p_year
    ORDER BY
      CASE g.category
        WHEN 'quantity' THEN 1
        WHEN 'regularity' THEN 2
        WHEN 'quality' THEN 3
      END
  ) goal_data;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

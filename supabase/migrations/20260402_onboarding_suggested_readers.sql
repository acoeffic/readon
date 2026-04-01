-- Migration : Lecteurs suggérés pour l'onboarding
-- Retourne des profils publics actifs pour que les nouveaux utilisateurs
-- puissent suivre des lecteurs et avoir un feed vivant dès le départ.

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
  recent_sessions BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH reader_stats AS (
    SELECT
      p.id AS uid,
      p.display_name,
      p.avatar_url,
      p.reading_habit,
      -- Livres terminés
      COALESCE((
        SELECT COUNT(*)
        FROM user_books ub
        WHERE ub.user_id = p.id AND ub.status = 'finished'
      ), 0) AS books_finished,
      -- Flow actuel (via reading_flow ou sessions récentes)
      COALESCE((
        SELECT current_flow
        FROM reading_flows rf
        WHERE rf.user_id = p.id
      ), 0) AS current_flow,
      -- Sessions dans les 14 derniers jours
      (
        SELECT COUNT(*)
        FROM reading_sessions rs
        WHERE rs.user_id = p.id
          AND rs.end_time IS NOT NULL
          AND rs.created_at > NOW() - INTERVAL '14 days'
      ) AS recent_sessions,
      -- Livre en cours (le plus récent)
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
      ) AS current_book_cover
    FROM profiles p
    WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
      AND p.id != auth.uid()
      -- Au moins 1 session complétée
      AND EXISTS (
        SELECT 1 FROM reading_sessions rs
        WHERE rs.user_id = p.id AND rs.end_time IS NOT NULL
      )
      -- Actif récemment (14 jours)
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
    rs.recent_sessions
  FROM reader_stats rs
  ORDER BY
    -- Prioriser les lecteurs avec le même reading_habit
    CASE WHEN p_reading_habit IS NOT NULL AND rs.reading_habit = p_reading_habit THEN 0 ELSE 1 END,
    -- Puis par activité récente
    rs.recent_sessions DESC,
    -- Puis par nombre de livres
    rs.books_finished DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_suggested_readers(TEXT, INTEGER) TO authenticated;

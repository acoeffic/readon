-- Migration : Ajouter hide_reading_hours aux profiles
-- Permet de cacher ses heures de lecture vis-a-vis des autres utilisateurs
-- tout en gardant les autres statistiques (livres, pages, flow) visibles.

-- =====================================================
-- 1. Ajouter la colonne hide_reading_hours
-- =====================================================
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS hide_reading_hours BOOLEAN DEFAULT FALSE;

-- =====================================================
-- 2. Mettre a jour get_friend_profile_stats
--    Retourner total_minutes = NULL si le profil cible
--    a hide_reading_hours = TRUE (sauf pour soi-meme)
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
      SELECT COUNT(*) FROM user_books
      WHERE user_id = p_user_id
        AND status = 'finished'
        AND is_hidden = FALSE
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
-- 3. Recreer mv_community_sessions
--    Nullifier start_time / end_time si hide_reading_hours
-- =====================================================
DROP MATERIALIZED VIEW IF EXISTS mv_community_sessions CASCADE;

CREATE MATERIALIZED VIEW mv_community_sessions AS
SELECT
  rs.id::text   AS session_id,
  rs.start_page,
  rs.end_page,
  CASE WHEN COALESCE(p.hide_reading_hours, FALSE) THEN NULL ELSE rs.start_time END AS start_time,
  CASE WHEN COALESCE(p.hide_reading_hours, FALSE) THEN NULL ELSE rs.end_time END AS end_time,
  rs.created_at AS session_created_at,
  p.display_name,
  p.avatar_url,
  p.id          AS user_id,
  b.title       AS book_title,
  b.author      AS book_author,
  b.cover_url   AS book_cover
FROM reading_sessions rs
JOIN profiles p ON p.id = rs.user_id
JOIN books b ON b.id::text = rs.book_id
LEFT JOIN user_books ub ON ub.book_id = b.id AND ub.user_id = rs.user_id
WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
  AND rs.end_time IS NOT NULL
  AND rs.created_at > NOW() - INTERVAL '24 hours'
  AND rs.is_hidden = FALSE
  AND COALESCE(ub.is_hidden, FALSE) = FALSE
ORDER BY rs.created_at DESC
LIMIT 100
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_community_sessions_id
  ON mv_community_sessions(session_id);

CREATE INDEX IF NOT EXISTS idx_mv_community_sessions_user
  ON mv_community_sessions(user_id);

-- Recreer la RPC qui lit la vue materialisee
CREATE OR REPLACE FUNCTION get_community_sessions(
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  session_id TEXT,
  start_page INTEGER,
  end_page INTEGER,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  session_created_at TIMESTAMPTZ,
  display_name TEXT,
  avatar_url TEXT,
  user_id UUID,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mv.session_id,
    mv.start_page,
    mv.end_page,
    mv.start_time,
    mv.end_time,
    mv.session_created_at,
    mv.display_name,
    mv.avatar_url,
    mv.user_id,
    mv.book_title,
    mv.book_author,
    mv.book_cover
  FROM mv_community_sessions mv
  WHERE mv.user_id != auth.uid()
  ORDER BY mv.session_created_at DESC
  LIMIT p_limit;
END;
$$;

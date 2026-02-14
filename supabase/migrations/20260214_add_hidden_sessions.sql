-- Migration : Ajouter is_hidden aux reading_sessions
-- Permet de cacher ses propres sessions vis-a-vis des autres utilisateurs
-- (feed, classements, profil ami) tout en les gardant dans les stats perso.

-- =====================================================
-- 1. Ajouter la colonne is_hidden
-- =====================================================
ALTER TABLE reading_sessions
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_reading_sessions_hidden
  ON reading_sessions(user_id, is_hidden);

-- =====================================================
-- 2. Mettre a jour get_friend_profile_stats
--    Exclure les sessions cachees ET les sessions de livres caches
-- =====================================================
CREATE OR REPLACE FUNCTION get_friend_profile_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
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
    'total_minutes', COALESCE((
      SELECT SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 60)
      FROM reading_sessions rs
      LEFT JOIN user_books ub ON ub.user_id = rs.user_id AND ub.book_id::text = rs.book_id
      WHERE rs.user_id = p_user_id
        AND rs.end_time IS NOT NULL
        AND rs.is_hidden = FALSE
        AND COALESCE(ub.is_hidden, FALSE) = FALSE
    ), 0)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- =====================================================
-- 3. Mettre a jour get_flow_percentile
--    Exclure les sessions cachees
-- =====================================================
CREATE OR REPLACE FUNCTION get_flow_percentile()
RETURNS INTEGER AS $$
DECLARE
  my_active_days INTEGER;
  total_users INTEGER;
  users_below INTEGER;
BEGIN
  -- Jours actifs de l'utilisateur courant sur les 30 derniers jours
  SELECT COUNT(DISTINCT DATE(end_time))
  INTO my_active_days
  FROM reading_sessions
  WHERE user_id = auth.uid()
    AND end_time >= NOW() - INTERVAL '30 days'
    AND is_hidden = FALSE;

  -- Compter les utilisateurs et ceux avec moins de jours actifs
  WITH user_days AS (
    SELECT user_id, COUNT(DISTINCT DATE(end_time)) as days
    FROM reading_sessions
    WHERE end_time >= NOW() - INTERVAL '30 days'
      AND is_hidden = FALSE
    GROUP BY user_id
  )
  SELECT COUNT(*), COUNT(*) FILTER (WHERE days < my_active_days)
  INTO total_users, users_below
  FROM user_days;

  IF total_users <= 1 THEN RETURN 0; END IF;
  RETURN LEAST(99, GREATEST(1, (users_below * 100 / total_users)));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- =====================================================
-- 4. Recreer les vues materialisees avec filtre is_hidden
-- =====================================================

-- 4a. Trending books : exclure sessions cachees et livres caches
DROP MATERIALIZED VIEW IF EXISTS mv_trending_books CASCADE;

CREATE MATERIALIZED VIEW mv_trending_books AS
SELECT
  b.id          AS book_id,
  b.title       AS book_title,
  b.author      AS book_author,
  b.cover_url   AS book_cover,
  COUNT(DISTINCT rs.id)      AS session_count,
  COUNT(DISTINCT rs.user_id) AS reader_count
FROM books b
JOIN reading_sessions rs ON rs.book_id = b.id::text
LEFT JOIN user_books ub ON ub.book_id = b.id AND ub.user_id = rs.user_id
WHERE rs.created_at > NOW() - INTERVAL '7 days'
  AND rs.end_time IS NOT NULL
  AND rs.is_hidden = FALSE
  AND COALESCE(ub.is_hidden, FALSE) = FALSE
GROUP BY b.id, b.title, b.author, b.cover_url
ORDER BY session_count DESC
LIMIT 20
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_trending_books_id
  ON mv_trending_books(book_id);

-- 4b. Community sessions : exclure sessions cachees et livres caches
DROP MATERIALIZED VIEW IF EXISTS mv_community_sessions CASCADE;

CREATE MATERIALIZED VIEW mv_community_sessions AS
SELECT
  rs.id::text   AS session_id,
  rs.start_page,
  rs.end_page,
  rs.start_time,
  rs.end_time,
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

-- =====================================================
-- 5. Recreer les RPCs qui lisent les vues materialisees
-- =====================================================

-- 5a. Trending books
CREATE OR REPLACE FUNCTION get_trending_books_by_sessions(
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  book_id BIGINT,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT,
  session_count BIGINT,
  reader_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mv.book_id,
    mv.book_title,
    mv.book_author,
    mv.book_cover,
    mv.session_count,
    mv.reader_count
  FROM mv_trending_books mv
  ORDER BY mv.session_count DESC
  LIMIT p_limit;
END;
$$;

-- 5b. Community sessions
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

-- =====================================================
-- 6. Replanifier le refresh pg_cron (inchangé)
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_namespace WHERE nspname = 'cron'
  ) THEN
    RAISE NOTICE 'pg_cron non disponible';
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_trending_books') THEN
    EXECUTE 'SELECT cron.unschedule(''refresh_trending_books'')';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_community_sessions') THEN
    EXECUTE 'SELECT cron.unschedule(''refresh_community_sessions'')';
  END IF;

  EXECUTE 'SELECT cron.schedule(''refresh_trending_books'', ''5 * * * *'', ''REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trending_books'')';
  EXECUTE 'SELECT cron.schedule(''refresh_community_sessions'', ''*/15 * * * *'', ''REFRESH MATERIALIZED VIEW CONCURRENTLY mv_community_sessions'')';
END;
$$;

-- Migration : Vues matérialisées pour trending books et community sessions
-- Élimine les JOINs lourds sur chaque appel client.
-- Refresh automatique via pg_cron.

-- ═══════════════════════════════════════════════════════════════
-- 1. Vue matérialisée : livres tendance (7 derniers jours)
--    Identique pour tous les utilisateurs → refresh toutes les heures.
-- ═══════════════════════════════════════════════════════════════
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_trending_books AS
SELECT
  b.id          AS book_id,
  b.title       AS book_title,
  b.author      AS book_author,
  b.cover_url   AS book_cover,
  COUNT(DISTINCT rs.id)      AS session_count,
  COUNT(DISTINCT rs.user_id) AS reader_count
FROM books b
JOIN reading_sessions rs ON rs.book_id = b.id::text
WHERE rs.created_at > NOW() - INTERVAL '7 days'
  AND rs.end_time IS NOT NULL
GROUP BY b.id, b.title, b.author, b.cover_url
ORDER BY session_count DESC
LIMIT 20  -- pré-calculer un peu plus que le p_limit habituel (5-10)
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_trending_books_id
  ON mv_trending_books(book_id);

-- ═══════════════════════════════════════════════════════════════
-- 2. Vue matérialisée : sessions communautaires (24 dernières heures)
--    Pré-calcule les JOINs profiles + books.
--    Le filtre auth.uid() est appliqué à la lecture par la RPC.
-- ═══════════════════════════════════════════════════════════════
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_community_sessions AS
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
WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
  AND rs.end_time IS NOT NULL
  AND rs.created_at > NOW() - INTERVAL '24 hours'
ORDER BY rs.created_at DESC
LIMIT 100  -- buffer pour filtrer auth.uid() ensuite
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_community_sessions_id
  ON mv_community_sessions(session_id);

CREATE INDEX IF NOT EXISTS idx_mv_community_sessions_user
  ON mv_community_sessions(user_id);

-- ═══════════════════════════════════════════════════════════════
-- 3. Fonction de refresh (appelable manuellement ou par cron)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION refresh_feed_materialized_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trending_books;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_community_sessions;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. Réécrire les RPC pour lire depuis les vues matérialisées
-- ═══════════════════════════════════════════════════════════════

-- 4a. Trending books : simple SELECT sur la MV
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

-- 4b. Community sessions : SELECT sur la MV + filtre auth.uid()
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

-- ═══════════════════════════════════════════════════════════════
-- 5. Planifier le refresh automatique via pg_cron
--    Trending : toutes les heures (données sur 7 jours, pas besoin de plus)
--    Community : toutes les 15 minutes (données sur 24h, fraîcheur importante)
-- ═══════════════════════════════════════════════════════════════

-- Note : pg_cron doit être activé dans le dashboard Supabase
-- (Database → Extensions → pg_cron → Enable)
-- Si pg_cron n'est pas activé, ce bloc est ignoré silencieusement.

DO $$
BEGIN
  -- Ne rien faire si pg_cron n'est pas installé
  IF NOT EXISTS (
    SELECT 1 FROM pg_namespace WHERE nspname = 'cron'
  ) THEN
    RAISE NOTICE 'pg_cron non disponible — les vues devront etre refresh manuellement via refresh_feed_materialized_views()';
    RETURN;
  END IF;

  -- Supprimer les anciens jobs s'ils existent
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_trending_books') THEN
    EXECUTE 'SELECT cron.unschedule(''refresh_trending_books'')';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_community_sessions') THEN
    EXECUTE 'SELECT cron.unschedule(''refresh_community_sessions'')';
  END IF;

  -- Trending books : refresh toutes les heures a :05
  EXECUTE 'SELECT cron.schedule(''refresh_trending_books'', ''5 * * * *'', ''REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trending_books'')';

  -- Community sessions : refresh toutes les 15 minutes
  EXECUTE 'SELECT cron.schedule(''refresh_community_sessions'', ''*/15 * * * *'', ''REFRESH MATERIALIZED VIEW CONCURRENTLY mv_community_sessions'')';
END;
$$;

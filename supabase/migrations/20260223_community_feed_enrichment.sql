-- Migration : Enrichissement du feed communautaire (cold start)
-- Ajoute deux nouvelles RPC pour les utilisateurs avec peu/pas d'amis :
-- 1. get_active_readers : lecteurs actuellement en session
-- 2. get_community_badge_unlocks : badges récemment débloqués

-- ═══════════════════════════════════════════════════════════════
-- 1. Index partiel pour les sessions actives (end_time IS NULL)
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_reading_sessions_active
  ON reading_sessions(start_time DESC)
  WHERE end_time IS NULL;

-- ═══════════════════════════════════════════════════════════════
-- 2. Index pour les badges débloqués récemment
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_user_badges_unlocked_at
  ON user_badges(unlocked_at DESC)
  WHERE unlocked_at IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- 3. RPC : Lecteurs actuellement en session (profils publics)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_active_readers(
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  session_id TEXT,
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  book_id TEXT,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT,
  start_time TIMESTAMPTZ,
  start_page INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    rs.id AS session_id,
    p.id AS user_id,
    p.display_name,
    p.avatar_url,
    rs.book_id,
    b.title AS book_title,
    b.author AS book_author,
    b.cover_url AS book_cover,
    rs.start_time,
    rs.start_page
  FROM reading_sessions rs
  JOIN profiles p ON p.id = rs.user_id
  JOIN books b ON b.id::text = rs.book_id
  WHERE rs.end_time IS NULL
    AND COALESCE(p.is_profile_private, FALSE) = FALSE
    AND rs.user_id != auth.uid()
  ORDER BY rs.start_time DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_active_readers(INTEGER) TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 4. RPC : Badges récemment débloqués par la communauté
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_community_badge_unlocks(
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  badge_id TEXT,
  badge_name TEXT,
  badge_icon TEXT,
  badge_color TEXT,
  badge_category TEXT,
  unlocked_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS user_id,
    p.display_name,
    p.avatar_url,
    b.id AS badge_id,
    b.name AS badge_name,
    b.icon AS badge_icon,
    b.color AS badge_color,
    b.category AS badge_category,
    ub.unlocked_at
  FROM user_badges ub
  JOIN badges b ON b.id = ub.badge_id
  JOIN profiles p ON p.id = ub.user_id
  WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
    AND ub.user_id != auth.uid()
    AND ub.unlocked_at > NOW() - INTERVAL '7 days'
    AND COALESCE(b.is_secret, FALSE) = FALSE
  ORDER BY ub.unlocked_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_community_badge_unlocks(INTEGER) TO authenticated;

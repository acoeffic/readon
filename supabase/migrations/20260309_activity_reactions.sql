-- =====================================================
-- Migration: Réactions emoji sur les activités du feed
-- Remplace l'ancien système reactions (fire/book/clap/heart)
-- par un système unifié avec emojis (1 réaction par user)
-- =====================================================

-- =====================================================
-- 1. TABLE activity_reactions
-- =====================================================
CREATE TABLE IF NOT EXISTS activity_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id BIGINT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Une seule réaction par utilisateur par activité
  UNIQUE(activity_id, user_id),
  CONSTRAINT valid_emoji CHECK (emoji IN ('❤️', '📚', '🔥', '🌟', '😭'))
);

CREATE INDEX IF NOT EXISTS idx_activity_reactions_activity
  ON activity_reactions(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_reactions_user
  ON activity_reactions(user_id);

-- =====================================================
-- 2. RLS POLICIES
-- =====================================================
ALTER TABLE activity_reactions ENABLE ROW LEVEL SECURITY;

-- Tout utilisateur authentifié peut voir les réactions
DROP POLICY IF EXISTS "Authenticated users can view activity reactions" ON activity_reactions;
CREATE POLICY "Authenticated users can view activity reactions"
  ON activity_reactions FOR SELECT TO authenticated
  USING (TRUE);

-- Un utilisateur peut insérer sa propre réaction
DROP POLICY IF EXISTS "Users can insert own activity reaction" ON activity_reactions;
CREATE POLICY "Users can insert own activity reaction"
  ON activity_reactions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Un utilisateur peut mettre à jour sa propre réaction
DROP POLICY IF EXISTS "Users can update own activity reaction" ON activity_reactions;
CREATE POLICY "Users can update own activity reaction"
  ON activity_reactions FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- Un utilisateur peut supprimer sa propre réaction
DROP POLICY IF EXISTS "Users can delete own activity reaction" ON activity_reactions;
CREATE POLICY "Users can delete own activity reaction"
  ON activity_reactions FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- 3. RPC: get_activity_emoji_reactions
-- =====================================================
CREATE OR REPLACE FUNCTION get_activity_emoji_reactions(p_activity_id BIGINT)
RETURNS JSON AS $$
DECLARE
  result JSON;
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();

  SELECT json_build_object(
    'counts', COALESCE((
      SELECT json_object_agg(emoji, cnt)
      FROM (
        SELECT emoji, COUNT(*) AS cnt
        FROM activity_reactions
        WHERE activity_id = p_activity_id
        GROUP BY emoji
      ) sub
    ), '{}'::json),
    'user_emoji', (
      SELECT emoji
      FROM activity_reactions
      WHERE activity_id = p_activity_id
      AND user_id = current_user_id
    ),
    'total', (
      SELECT COUNT(*) FROM activity_reactions WHERE activity_id = p_activity_id
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

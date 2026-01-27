-- =====================================================
-- Migration: Premium + Réactions avancées
-- Ajoute le statut premium aux profils et une table
-- de réactions avancées pour les activités
-- =====================================================

-- =====================================================
-- 1. PREMIUM STATUS sur profiles
-- =====================================================
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS premium_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_is_premium
ON profiles(is_premium) WHERE is_premium = TRUE;

-- =====================================================
-- 2. TABLE REACTIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS reactions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  activity_id INT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Un utilisateur ne peut avoir qu'une seule réaction par type par activité
  UNIQUE(activity_id, user_id, reaction_type),
  CONSTRAINT valid_reaction_type CHECK (reaction_type IN ('fire', 'book', 'clap', 'heart'))
);

CREATE INDEX idx_reactions_activity ON reactions(activity_id);
CREATE INDEX idx_reactions_user ON reactions(user_id);
CREATE INDEX idx_reactions_activity_type ON reactions(activity_id, reaction_type);

-- =====================================================
-- 3. RLS POLICIES
-- =====================================================
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

-- Tout utilisateur authentifié peut voir les réactions
CREATE POLICY "Authenticated users can view reactions"
  ON reactions FOR SELECT TO authenticated
  USING (TRUE);

-- Seuls les utilisateurs premium peuvent insérer des réactions
CREATE POLICY "Premium users can insert reactions"
  ON reactions FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_premium = TRUE
    )
  );

-- Un utilisateur peut supprimer ses propres réactions
CREATE POLICY "Users can delete own reactions"
  ON reactions FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- 4. RPC: get_activity_reactions
-- =====================================================
CREATE OR REPLACE FUNCTION get_activity_reactions(p_activity_id INT)
RETURNS JSON AS $$
DECLARE
  result JSON;
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();

  SELECT json_build_object(
    'counts', COALESCE((
      SELECT json_object_agg(reaction_type, cnt)
      FROM (
        SELECT reaction_type, COUNT(*) AS cnt
        FROM reactions
        WHERE activity_id = p_activity_id
        GROUP BY reaction_type
      ) sub
    ), '{}'::json),
    'user_reactions', COALESCE((
      SELECT json_agg(reaction_type)
      FROM reactions
      WHERE activity_id = p_activity_id
      AND user_id = current_user_id
    ), '[]'::json),
    'total', (
      SELECT COUNT(*) FROM reactions WHERE activity_id = p_activity_id
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. RPC: check_premium_status
-- =====================================================
CREATE OR REPLACE FUNCTION check_premium_status()
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_is_premium BOOLEAN;
  v_premium_until TIMESTAMPTZ;
BEGIN
  SELECT is_premium, premium_until
  INTO v_is_premium, v_premium_until
  FROM profiles
  WHERE id = auth.uid();

  -- Auto-expiration: si premium_until est passé, désactiver
  IF v_is_premium AND v_premium_until IS NOT NULL AND v_premium_until < NOW() THEN
    UPDATE profiles
    SET is_premium = FALSE
    WHERE id = auth.uid();
    v_is_premium := FALSE;
  END IF;

  SELECT json_build_object(
    'is_premium', COALESCE(v_is_premium, FALSE),
    'premium_until', v_premium_until
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

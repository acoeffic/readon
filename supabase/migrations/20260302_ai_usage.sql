-- Migration: Table ai_usage pour tracker la consommation IA (résumés, etc.)
-- + Fonction RPC pour compter l'utilisation mensuelle

-- ============================================================================
-- 1. Table ai_usage
-- ============================================================================

CREATE TABLE ai_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature TEXT NOT NULL DEFAULT 'summary',
  used_at TIMESTAMPTZ DEFAULT now()
);

-- Index pour les requêtes de comptage par mois
CREATE INDEX idx_ai_usage_user_month ON ai_usage (user_id, feature, used_at);

-- ============================================================================
-- 2. RLS
-- ============================================================================

ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own usage"
  ON ai_usage FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own usage"
  ON ai_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 3. Fonction RPC : compter l'utilisation du mois en cours
-- ============================================================================

CREATE OR REPLACE FUNCTION get_ai_usage_count(
  p_feature TEXT DEFAULT 'summary'
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER FROM ai_usage
    WHERE user_id = auth.uid()
      AND feature = p_feature
      AND used_at >= date_trunc('month', now())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

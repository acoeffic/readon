-- ============================================================================
-- MIGRATION: Table monthly_wrapped_shares pour le pré-render vidéo Remotion
-- ============================================================================
-- Même pattern que user_books.share_video_* mais pour les monthly wrapped.
-- Une entrée par user/month/year.
-- ============================================================================

-- ============================================================================
-- 1. TABLE monthly_wrapped_shares
-- ============================================================================

CREATE TABLE IF NOT EXISTS monthly_wrapped_shares (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month         SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
  year          SMALLINT NOT NULL CHECK (year BETWEEN 2020 AND 2099),
  video_url     TEXT,
  image_url     TEXT,
  video_status  TEXT DEFAULT NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),

  UNIQUE (user_id, month, year)
);

COMMENT ON COLUMN monthly_wrapped_shares.video_status IS
  'null=not requested, pending, rendering, done, error';

-- Index pour lookups rapides
CREATE INDEX IF NOT EXISTS idx_monthly_wrapped_shares_lookup
  ON monthly_wrapped_shares(user_id, month, year);

-- ============================================================================
-- 2. RLS
-- ============================================================================

ALTER TABLE monthly_wrapped_shares ENABLE ROW LEVEL SECURITY;

-- Les utilisateurs peuvent lire leurs propres entrées
CREATE POLICY "Users can read own monthly wrapped shares"
  ON monthly_wrapped_shares FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Insert/update par service role uniquement (readon-sync)
CREATE POLICY "Service role insert monthly wrapped shares"
  ON monthly_wrapped_shares FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role update monthly wrapped shares"
  ON monthly_wrapped_shares FOR UPDATE
  TO service_role
  USING (true);

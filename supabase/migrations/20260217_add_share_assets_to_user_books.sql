-- ============================================================================
-- MIGRATION: Colonnes share assets sur user_books + bucket Storage "shares"
-- ============================================================================
-- Permet le pré-render de vidéos Remotion pour le partage "livre terminé".
-- Les assets sont per-user-per-book (pas sur la table books partagée).
-- ============================================================================

-- ============================================================================
-- 1. COLONNES SHARE SUR user_books
-- ============================================================================

ALTER TABLE user_books ADD COLUMN IF NOT EXISTS share_video_url TEXT;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS share_image_url TEXT;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS share_video_status TEXT;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS dominant_color TEXT;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS secondary_color TEXT;

COMMENT ON COLUMN user_books.share_video_status IS
  'null=not requested, pending, rendering, done, error';

-- Index pour lookups rapides par le serveur
CREATE INDEX IF NOT EXISTS idx_user_books_share_status
  ON user_books(user_id, book_id)
  WHERE share_video_status IS NOT NULL;

-- ============================================================================
-- 2. BUCKET STORAGE "shares" (public)
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('shares', 'shares', true)
ON CONFLICT (id) DO NOTHING;

-- Lecture publique (les URLs de partage doivent être accessibles par tous)
CREATE POLICY "Public read access on shares"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'shares');

-- Upload/update par service role uniquement (readon-sync utilise le service_role key)
CREATE POLICY "Service role upload on shares"
  ON storage.objects FOR INSERT
  TO service_role
  WITH CHECK (bucket_id = 'shares');

CREATE POLICY "Service role update on shares"
  ON storage.objects FOR UPDATE
  TO service_role
  USING (bucket_id = 'shares');

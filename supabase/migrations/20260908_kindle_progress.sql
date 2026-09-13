-- ============================================================================
-- Migration: progression Kindle sur user_books
-- ----------------------------------------------------------------------------
-- Le sync Kindle lit désormais l'API JSON du Cloud Reader
-- (read.amazon.com/kindle-library/search) qui fournit, par livre, l'ASIN et le
-- pourcentage lu. On les stocke sur user_books ; la page courante affichée
-- dans l'app devient max(end_page des sessions, kindle_percent × page_count).
-- Aucune session n'est créée : les stats/badges/feed ne sont pas touchés.
-- ============================================================================

ALTER TABLE user_books ADD COLUMN IF NOT EXISTS kindle_asin TEXT;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS kindle_percent SMALLINT
  CHECK (kindle_percent IS NULL OR (kindle_percent >= 0 AND kindle_percent <= 100));
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS kindle_progress_at TIMESTAMPTZ;

COMMENT ON COLUMN user_books.kindle_asin IS
  'ASIN Amazon du livre tel que vu dans la bibliothèque Kindle de l''utilisateur';
COMMENT ON COLUMN user_books.kindle_percent IS
  'Pourcentage lu rapporté par Kindle (0-100). NULL = jamais synchronisé';
COMMENT ON COLUMN user_books.kindle_progress_at IS
  'Horodatage du dernier sync ayant mis à jour kindle_percent';

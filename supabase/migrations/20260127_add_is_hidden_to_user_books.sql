-- =====================================================
-- Migration: add is_hidden to user_books
-- Permet de masquer certains livres vis-à-vis des
-- autres utilisateurs (profil ami, recherche, etc.)
-- Le livre reste visible dans la bibliothèque perso.
-- =====================================================

ALTER TABLE user_books
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_user_books_is_hidden
  ON user_books(user_id, is_hidden);

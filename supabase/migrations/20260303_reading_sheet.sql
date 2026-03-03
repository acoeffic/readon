-- Migration: Ajouter reading_sheet JSONB sur user_books
-- Stocke la fiche de lecture IA générée à partir des annotations

ALTER TABLE user_books ADD COLUMN IF NOT EXISTS reading_sheet JSONB;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS reading_sheet_generated_at TIMESTAMPTZ;

COMMENT ON COLUMN user_books.reading_sheet IS
  'AI-generated structured reading sheet: {themes, quotes, progression, synthesis}';

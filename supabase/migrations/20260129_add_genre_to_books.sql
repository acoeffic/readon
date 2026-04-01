-- Ajouter la colonne genre à la table books
ALTER TABLE books ADD COLUMN IF NOT EXISTS genre TEXT;

-- Index pour filtrer/grouper par genre
CREATE INDEX IF NOT EXISTS idx_books_genre ON books(genre);

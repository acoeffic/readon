-- Migration pour corriger les policies RLS de la table user_books
-- Cette table lie les utilisateurs à leurs livres

-- 1. Activer RLS sur la table user_books si ce n'est pas déjà fait
ALTER TABLE user_books ENABLE ROW LEVEL SECURITY;

-- 2. Supprimer les anciennes policies si elles existent
DROP POLICY IF EXISTS "Users can view their own books" ON user_books;
DROP POLICY IF EXISTS "Users can insert their own books" ON user_books;
DROP POLICY IF EXISTS "Users can update their own books" ON user_books;
DROP POLICY IF EXISTS "Users can delete their own books" ON user_books;

-- 3. Créer les nouvelles policies

-- Policy pour SELECT : Les utilisateurs ne voient que leurs propres livres
CREATE POLICY "Users can view their own books"
ON user_books
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Policy pour INSERT : Les utilisateurs peuvent ajouter des livres à leur bibliothèque
CREATE POLICY "Users can insert their own books"
ON user_books
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy pour UPDATE : Les utilisateurs peuvent mettre à jour leurs propres livres
CREATE POLICY "Users can update their own books"
ON user_books
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy pour DELETE : Les utilisateurs peuvent supprimer des livres de leur bibliothèque
CREATE POLICY "Users can delete their own books"
ON user_books
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

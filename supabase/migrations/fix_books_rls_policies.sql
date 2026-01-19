-- Migration pour corriger les policies RLS de la table books
-- Cette migration permet aux utilisateurs authentifiés d'ajouter des livres

-- 1. Activer RLS sur la table books si ce n'est pas déjà fait
ALTER TABLE books ENABLE ROW LEVEL SECURITY;

-- 2. Supprimer les anciennes policies si elles existent
DROP POLICY IF EXISTS "Users can view all books" ON books;
DROP POLICY IF EXISTS "Users can insert books" ON books;
DROP POLICY IF EXISTS "Users can update their own books" ON books;

-- 3. Créer les nouvelles policies

-- Policy pour SELECT : Tous les utilisateurs authentifiés peuvent voir tous les livres
CREATE POLICY "Users can view all books"
ON books
FOR SELECT
TO authenticated
USING (true);

-- Policy pour INSERT : Tous les utilisateurs authentifiés peuvent ajouter des livres
CREATE POLICY "Users can insert books"
ON books
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy pour UPDATE : Les utilisateurs peuvent mettre à jour n'importe quel livre
-- (car les livres sont partagés entre tous les utilisateurs)
CREATE POLICY "Users can update books"
ON books
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Note: Pas de policy DELETE car on ne veut pas que les utilisateurs puissent supprimer des livres
-- qui pourraient être utilisés par d'autres utilisateurs

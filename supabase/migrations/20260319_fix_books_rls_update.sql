-- Migration : Restreindre UPDATE sur la table books
-- Problème : la policy actuelle permet à tout utilisateur authentifié de modifier
-- n'importe quel champ (titre, auteur, etc.) de n'importe quel livre.
-- Solution : supprimer la policy UPDATE et créer une fonction SECURITY DEFINER
-- qui n'autorise que la mise à jour des champs de métadonnées (enrichissement).

-- 1. Supprimer la policy UPDATE existante
DROP POLICY IF EXISTS "Users can update books" ON books;
DROP POLICY IF EXISTS "Users can update their own books" ON books;

-- 2. Créer une fonction sécurisée pour enrichir les métadonnées d'un livre
CREATE OR REPLACE FUNCTION update_book_metadata(
  p_book_id bigint,
  p_cover_url text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_page_count int DEFAULT NULL,
  p_author text DEFAULT NULL,
  p_genre text DEFAULT NULL,
  p_google_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Vérifier que l'utilisateur est authentifié
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  -- Vérifier que le livre existe ET que l'utilisateur l'a dans sa bibliothèque
  IF NOT EXISTS (
    SELECT 1 FROM user_books
    WHERE book_id = p_book_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Livre non trouvé dans votre bibliothèque';
  END IF;

  -- Mettre à jour uniquement les champs fournis (non NULL)
  UPDATE books SET
    cover_url   = COALESCE(p_cover_url, cover_url),
    description = COALESCE(p_description, description),
    page_count  = COALESCE(p_page_count, page_count),
    author      = COALESCE(p_author, author),
    genre       = COALESCE(p_genre, genre),
    google_id   = COALESCE(p_google_id, google_id)
  WHERE id = p_book_id;
END;
$$;

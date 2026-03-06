-- Migration : Sécuriser INSERT sur la table books
-- Problème : la policy actuelle permet à tout utilisateur authentifié d'insérer
-- n'importe quoi dans le catalogue partagé de livres.
-- Solution : supprimer la policy INSERT et créer une fonction SECURITY DEFINER
-- qui vérifie les données et gère les doublons.

-- 1. Supprimer la policy INSERT existante
DROP POLICY IF EXISTS "Users can insert books" ON books;

-- 2. Créer une fonction sécurisée pour insérer un livre
CREATE OR REPLACE FUNCTION insert_book_if_not_exists(
  p_title       text,
  p_author      text    DEFAULT NULL,
  p_isbn        text    DEFAULT NULL,
  p_cover_url   text    DEFAULT NULL,
  p_page_count  int     DEFAULT NULL,
  p_description text    DEFAULT NULL,
  p_google_id   text    DEFAULT NULL,
  p_source      text    DEFAULT 'manual',
  p_publisher   text    DEFAULT NULL,
  p_language    text    DEFAULT 'fr',
  p_genre       text    DEFAULT NULL,
  p_published_date text DEFAULT NULL,
  p_external_id text    DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_book_id bigint;
BEGIN
  -- Vérifier que l'utilisateur est authentifié
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  -- Validation des champs
  IF p_title IS NULL OR char_length(trim(p_title)) < 1 THEN
    RAISE EXCEPTION 'Le titre est obligatoire';
  END IF;
  IF char_length(p_title) > 500 THEN
    RAISE EXCEPTION 'Titre trop long (max 500 caractères)';
  END IF;
  IF p_description IS NOT NULL AND char_length(p_description) > 5000 THEN
    RAISE EXCEPTION 'Description trop longue (max 5000 caractères)';
  END IF;
  IF p_author IS NOT NULL AND char_length(p_author) > 500 THEN
    RAISE EXCEPTION 'Auteur trop long (max 500 caractères)';
  END IF;

  -- Vérifier les doublons par google_id
  IF p_google_id IS NOT NULL AND char_length(trim(p_google_id)) > 0 THEN
    SELECT id INTO v_book_id FROM books WHERE google_id = p_google_id LIMIT 1;
    IF v_book_id IS NOT NULL THEN
      RETURN v_book_id;
    END IF;
  END IF;

  -- Vérifier les doublons par titre + auteur (via la fonction existante)
  SELECT check_duplicate_book_by_title_author(p_title, p_author) INTO v_book_id;
  IF v_book_id IS NOT NULL AND v_book_id > 0 THEN
    RETURN v_book_id;
  END IF;

  -- Insérer le nouveau livre
  INSERT INTO books (
    title, author, isbn, cover_url, page_count, description,
    google_id, source, publisher, language, genre, published_date, external_id
  ) VALUES (
    trim(p_title), p_author, p_isbn, p_cover_url, p_page_count, p_description,
    p_google_id, COALESCE(p_source, 'manual'), p_publisher,
    COALESCE(p_language, 'fr'), p_genre, p_published_date, p_external_id
  )
  RETURNING id INTO v_book_id;

  RETURN v_book_id;
END;
$$;

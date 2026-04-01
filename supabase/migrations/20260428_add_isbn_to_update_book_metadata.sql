-- Ajouter le paramètre p_isbn à la fonction update_book_metadata
-- pour permettre l'enrichissement de l'ISBN depuis Google Books.

CREATE OR REPLACE FUNCTION update_book_metadata(
  p_book_id bigint,
  p_cover_url text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_page_count int DEFAULT NULL,
  p_author text DEFAULT NULL,
  p_genre text DEFAULT NULL,
  p_google_id text DEFAULT NULL,
  p_isbn text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifie';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM user_books
    WHERE book_id = p_book_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Livre non trouve dans votre bibliotheque';
  END IF;

  UPDATE books SET
    cover_url   = COALESCE(p_cover_url, cover_url),
    description = COALESCE(p_description, description),
    page_count  = COALESCE(p_page_count, page_count),
    author      = COALESCE(p_author, author),
    genre       = COALESCE(p_genre, genre),
    google_id   = COALESCE(p_google_id, google_id),
    isbn        = COALESCE(p_isbn, isbn)
  WHERE id = p_book_id;
END;
$$;

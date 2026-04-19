-- =====================================================
-- Migration: Auto-create activity when reading session ends
--
-- Problème : l'activité reading_session était créée côté
-- client (Dart) dans un try/catch silencieux. Quand la
-- session se terminait offline ou que l'INSERT échouait,
-- l'activité n'était jamais créée → pas de fan-out → le
-- feed des amis ne se mettait pas à jour.
--
-- Solution : trigger AFTER UPDATE sur reading_sessions
-- qui crée automatiquement l'activité quand end_time
-- passe de NULL à non-NULL. Le trigger fan_out_activity
-- existant distribue ensuite aux amis via feed_items.
-- =====================================================

CREATE OR REPLACE FUNCTION create_activity_on_session_end()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_book      RECORD;
  v_book_id   BIGINT;
  v_pages     INT;
  v_minutes   INT;
BEGIN
  -- Ne se déclencher que quand end_time passe de NULL à non-NULL
  IF OLD.end_time IS NOT NULL OR NEW.end_time IS NULL THEN
    RETURN NEW;
  END IF;

  -- Essayer de parser book_id comme entier (FK vers books)
  BEGIN
    v_book_id := NEW.book_id::BIGINT;
  EXCEPTION WHEN OTHERS THEN
    -- book_id non numérique → on ne peut pas joindre books
    RETURN NEW;
  END;

  -- Récupérer les métadonnées du livre
  SELECT title, author, cover_url, isbn, google_id
  INTO v_book
  FROM books
  WHERE id = v_book_id;

  -- Si le livre n'existe pas, ne rien faire
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- Calculer pages lues et durée
  v_pages := COALESCE(NEW.end_page, 0) - COALESCE(NEW.start_page, 0);
  v_minutes := EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))::INT / 60;

  -- Vérifier qu'une activité reading_session n'existe pas déjà pour cette session
  -- (le client Dart crée aussi l'activité côté app — éviter les doublons
  -- pendant la période de transition avant suppression du code client)
  IF EXISTS (
    SELECT 1 FROM activities
    WHERE author_id = NEW.user_id
      AND type = 'reading_session'
      AND payload->>'book_id' = v_book_id::text
      AND created_at BETWEEN NEW.end_time - INTERVAL '2 minutes'
                         AND NEW.end_time + INTERVAL '2 minutes'
  ) THEN
    RETURN NEW;
  END IF;

  -- Créer l'activité (le trigger fan_out_activity se charge du reste)
  INSERT INTO activities (author_id, type, payload, created_at)
  VALUES (
    NEW.user_id,
    'reading_session',
    jsonb_build_object(
      'book_id',          v_book_id,
      'book_title',       v_book.title,
      'book_author',      v_book.author,
      'book_cover',       v_book.cover_url,
      'book_isbn',        v_book.isbn,
      'book_google_id',   v_book.google_id,
      'pages_read',       v_pages,
      'duration_minutes', v_minutes,
      'start_page',       NEW.start_page,
      'end_page',         NEW.end_page
    ),
    NEW.end_time
  );

  RETURN NEW;
END;
$$;

-- Trigger AFTER UPDATE (pas BEFORE, pour ne pas bloquer le UPDATE si le trigger échoue)
DROP TRIGGER IF EXISTS trg_create_activity_on_session_end ON reading_sessions;
CREATE TRIGGER trg_create_activity_on_session_end
  AFTER UPDATE ON reading_sessions
  FOR EACH ROW
  EXECUTE FUNCTION create_activity_on_session_end();

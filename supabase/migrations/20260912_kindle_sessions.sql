-- ============================================================================
-- Sessions de lecture créées depuis la progression Kindle
-- ----------------------------------------------------------------------------
-- Quand le sync Kindle constate que le pourcentage lu d'un livre a augmenté
-- depuis le sync précédent, l'app crée une session (is_manual = true,
-- source = 'kindle') couvrant le delta de pages, avec une durée ESTIMÉE
-- (rythme personnel). `source` permet de la distinguer partout (feed, détail,
-- stats). NULL = session trackée dans l'app ou saisie manuellement.
-- Le trigger feed recopie `source` dans le payload de l'activité pour que la
-- carte amis puisse afficher le badge Kindle.
-- ============================================================================

ALTER TABLE reading_sessions ADD COLUMN IF NOT EXISTS source TEXT;
COMMENT ON COLUMN reading_sessions.source IS
  'NULL = app/manuel ; ''kindle'' = créée depuis la progression Kindle (durée estimée)';

CREATE OR REPLACE FUNCTION public.create_activity_on_session_end()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_book     RECORD;
  v_book_id  BIGINT;
  v_pages    INT;
  v_minutes  INT;
BEGIN
  IF OLD.end_time IS NOT NULL OR NEW.end_time IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_book_id := NEW.book_id::BIGINT;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  SELECT title, author, cover_url, isbn, google_id
  INTO v_book
  FROM books
  WHERE id = v_book_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_pages   := COALESCE(NEW.end_page, 0) - COALESCE(NEW.start_page, 0);
  v_minutes := EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))::INT / 60;

  IF EXISTS (
    SELECT 1 FROM activities
    WHERE author_id = NEW.user_id
      AND type = 'reading_session'
      AND payload->>'session_id' = NEW.id::text
  ) THEN
    RETURN NEW;
  END IF;

  BEGIN
    INSERT INTO activities (author_id, type, payload, created_at)
    VALUES (
      NEW.user_id,
      'reading_session',
      jsonb_build_object(
        'session_id',       NEW.id,
        'book_id',          v_book_id,
        'book_title',       v_book.title,
        'book_author',      v_book.author,
        'book_cover',       v_book.cover_url,
        'book_isbn',        v_book.isbn,
        'book_google_id',   v_book.google_id,
        'pages_read',       v_pages,
        'duration_minutes', v_minutes,
        'start_page',       NEW.start_page,
        'end_page',         NEW.end_page,
        'source',           NEW.source
      ),
      NEW.end_time
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'create_activity_on_session_end suppressed % %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

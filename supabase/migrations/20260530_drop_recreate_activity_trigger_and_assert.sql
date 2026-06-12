-- =====================================================
-- Migration: DROP explicite + recréation + assertion runtime.
--
-- 20260526, 20260528 et 20260529 ont toutes prétendu déployer une
-- version de create_activity_on_session_end qui swallow le duplicate
-- (ON CONFLICT puis EXCEPTION block). Pourtant le client continue de
-- voir 23505 lors de la fin de session. Donc la fonction effectivement
-- en prod n'est PAS celle qu'on pousse — soit `supabase db push`
-- skip silencieusement, soit une autre source écrase la définition.
--
-- On force ici un DROP puis CREATE FUNCTION (pas OR REPLACE) — si la
-- migration tourne vraiment, l'objet est nécessairement remplacé. On
-- ajoute aussi une assertion à la fin qui vérifie que la définition
-- contient bien le mot "EXCEPTION" — si la migration est marquée
-- appliquée mais que la fonction effective ne match pas, cette
-- assertion explosera bruyamment dans les logs Supabase.
-- =====================================================

DROP TRIGGER IF EXISTS trg_create_activity_on_session_end ON reading_sessions;
DROP FUNCTION IF EXISTS create_activity_on_session_end() CASCADE;

CREATE FUNCTION create_activity_on_session_end()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
        'end_page',         NEW.end_page
      ),
      NEW.end_time
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'create_activity_on_session_end suppressed % %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_activity_on_session_end
  AFTER UPDATE ON reading_sessions
  FOR EACH ROW
  EXECUTE FUNCTION create_activity_on_session_end();

-- Assertion runtime : si la fonction effective n'a pas notre bloc EXCEPTION,
-- on explose la migration. Permet de détecter immédiatement un déploiement
-- qui prétend réussir mais qui ne change rien en prod.
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.create_activity_on_session_end'::regproc)
    INTO v_def;
  IF v_def NOT LIKE '%EXCEPTION%' THEN
    RAISE EXCEPTION 'create_activity_on_session_end installation failed — definition lacks EXCEPTION block (got: %)', left(v_def, 200);
  END IF;
  RAISE NOTICE 'create_activity_on_session_end installed OK with EXCEPTION block';
END;
$$;

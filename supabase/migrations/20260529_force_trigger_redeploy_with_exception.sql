-- =====================================================
-- Migration: forcer un redéploiement complet du trigger
-- create_activity_on_session_end + utiliser BEGIN/EXCEPTION
-- (plus robuste que ON CONFLICT pour un index unique partiel).
--
-- Contexte
-- --------
-- 20260526 et 20260528 redéfinissent toutes deux la fonction avec
-- `INSERT ... ON CONFLICT DO NOTHING`. Pourtant, en prod, l'erreur
-- 23505 sur `uq_activities_reading_session_session_id` continue de
-- remonter au client lors de la fin de session — la fonction réelle
-- en prod ne contient toujours pas le bloc de dédup attendu.
--
-- Hypothèse : `ON CONFLICT (col, (expr)) WHERE ...` ne match pas
-- correctement l'index unique partiel `uq_activities_reading_session_session_id`
-- (PostgreSQL exige une correspondance EXACTE des expressions, y compris
-- les parenthèses). Si le matching échoue, ON CONFLICT n'a aucun effet
-- et l'erreur de duplicate remonte.
--
-- Fix
-- ---
-- 1. DROP + CREATE le trigger (force le rebind même si la fonction n'a
--    pas changé entre les déploiements).
-- 2. Remplacer ON CONFLICT par un bloc BEGIN/EXCEPTION qui catch
--    explicitement `unique_violation` ET tout autre SQLSTATE pour
--    garantir que le trigger ne fait JAMAIS rollback la transaction
--    UPDATE de reading_sessions. C'est moins élégant mais infaillible.
-- =====================================================

CREATE OR REPLACE FUNCTION create_activity_on_session_end()
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

  -- Dédup primaire : skip si une activité existe déjà pour cette session.
  IF EXISTS (
    SELECT 1 FROM activities
    WHERE author_id = NEW.user_id
      AND type = 'reading_session'
      AND payload->>'session_id' = NEW.id::text
  ) THEN
    RETURN NEW;
  END IF;

  -- Insertion protégée par EXCEPTION : on garantit qu'AUCUNE exception
  -- côté activities ne peut faire rollback l'UPDATE de reading_sessions.
  -- Catcher OTHERS et pas seulement unique_violation est défensif —
  -- une activité ratée est moins grave qu'une session qui ne se termine pas.
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
    WHEN unique_violation THEN
      NULL;
    WHEN OTHERS THEN
      RAISE WARNING 'create_activity_on_session_end: insert failed (%): %',
        SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Force le rebind du trigger pour s'assurer qu'il appelle bien la
-- nouvelle version de la fonction (au cas où l'attachement aurait été
-- altéré manuellement).
DROP TRIGGER IF EXISTS trg_create_activity_on_session_end ON reading_sessions;
CREATE TRIGGER trg_create_activity_on_session_end
  AFTER UPDATE ON reading_sessions
  FOR EACH ROW
  EXECUTE FUNCTION create_activity_on_session_end();

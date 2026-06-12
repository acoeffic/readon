-- =====================================================
-- Migration: rendre create_activity_on_session_end strictement
-- idempotent via INSERT ... ON CONFLICT DO NOTHING.
--
-- Contexte
-- --------
-- En 20260525, la fonction avait deux garde-fous : un `IF EXISTS` puis
-- un `BEGIN ... EXCEPTION WHEN unique_violation`. En prod, on voit
-- malgré tout remonter au client une erreur `23505` sur
-- `uq_activities_reading_session_session_id` lors de l'UPDATE d'une
-- session (signalée comme PostgrestException 409 côté Dart).
--
-- Cause probable : la fonction effectivement déployée diffère de la
-- version source (déploiement partiel d'une variante antérieure de
-- 20260525, ou édition manuelle), donc l'EXCEPTION n'est plus là.
-- On n'a pas accès au texte exact de la fonction en prod — on force
-- une définition robuste, qui ne dépend pas d'un bloc PL/pgSQL pour
-- swallow l'erreur.
--
-- Fix
-- ---
-- On utilise `INSERT INTO activities (...) ON CONFLICT
-- (author_id, ((payload->>'session_id')))
--  WHERE type = 'reading_session' AND payload ? 'session_id'
-- DO NOTHING`. La syntaxe `ON CONFLICT` sur un index unique
-- partiel doit reprendre EXACTEMENT la liste des colonnes/expressions
-- ET le prédicat partiel de l'index `uq_activities_reading_session_session_id`.
-- En cas de conflit, le statement est no-op : aucune erreur n'est levée.
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
  )
  ON CONFLICT (author_id, ((payload->>'session_id')))
    WHERE type = 'reading_session' AND payload ? 'session_id'
  DO NOTHING;

  RETURN NEW;
END;
$$;

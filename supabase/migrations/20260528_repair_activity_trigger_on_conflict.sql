-- =====================================================
-- Migration: réapplique le fix ON CONFLICT DO NOTHING sur le trigger
-- create_activity_on_session_end.
--
-- Contexte
-- --------
-- La migration 20260526 redéfinissait déjà cette fonction avec
-- `INSERT ... ON CONFLICT DO NOTHING`, mais en prod on continue à voir
-- remonter une erreur 23505 sur `uq_activities_reading_session_session_id`
-- au moment de terminer une session de lecture (PostgrestException 409
-- côté Dart, qui rollback l'UPDATE de reading_sessions et empêche
-- l'utilisateur de terminer sa session).
--
-- Cause probable : la définition effective de la fonction a divergé du
-- source de 20260526 (édition manuelle via Supabase Studio, ou déploiement
-- partiel) — `migration list` dit que 20260526 est appliquée, mais la
-- fonction réelle ne contient pas le bloc ON CONFLICT.
--
-- Fix : on force une re-définition identique au source de 20260526. Comme
-- c'est une nouvelle migration, elle sera systématiquement appliquée par
-- `supabase db push` (pas de skip "already applied").
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

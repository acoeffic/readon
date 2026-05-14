-- =====================================================
-- Migration: dédup robuste des activités reading_session par session_id
--
-- Problème
-- --------
-- `create_activity_on_session_end` (20260512) dédupliquait par une fenêtre
-- temporelle ±2 min sur `created_at`. Quand une session est resumée puis
-- re-terminée plus de 2 min plus tard (recovery modal, auto-pause 4 h,
-- stale notif), le trigger fire à nouveau (OLD.end_time est NULL après le
-- resume), la fenêtre temporelle ne couvre plus la 1ère activité, et une
-- 2ème activité dupliquée est créée → fan_out_activity crée une 2ème
-- feed_items avec un activity_id différent → carte affichée en doublon
-- côté client.
--
-- Fix
-- ---
--   1. Cleanup : supprimer les activités reading_session dupliquées
--      existantes (CASCADE nettoie feed_items).
--   2. Backfill : populer payload->session_id sur les activités
--      historiques quand on peut retrouver la session associée.
--   3. Index unique partiel sur (author_id, payload->>'session_id')
--      pour type='reading_session' → garde-fou final.
--   4. Trigger refait : stocke session_id dans le payload, dédup par
--      session_id (et plus par fenêtre temporelle), avec
--      EXCEPTION WHEN unique_violation pour gérer une éventuelle race.
-- =====================================================

BEGIN;

-- ─── 1. Cleanup des doublons existants ──────────────────────────────────
-- On garde l'activité au plus petit id (la 1ère créée) par grappe
-- (author_id, book_id, start_page, end_page). Les feed_items pointant vers
-- les activités supprimées sont nettoyés via ON DELETE CASCADE.

WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY
             author_id,
             payload->>'book_id',
             payload->>'start_page',
             payload->>'end_page'
           ORDER BY id
         ) AS rn
  FROM activities
  WHERE type = 'reading_session'
)
DELETE FROM activities
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- ─── 2. Backfill session_id sur les activités historiques ───────────────
-- Best-effort : on lie chaque activité reading_session sans session_id à
-- sa reading_sessions correspondante par user_id + book_id + start_page +
-- end_page + end_time proche (±120 s). Si ambigu (plusieurs candidats),
-- l'UPDATE garde le 1er match — au pire, le session_id restera NULL pour
-- ces lignes et l'index unique partiel ne les couvrira pas (mais le fix
-- client dédup défensif est déjà en place pour ces cas).

UPDATE activities a
SET payload = a.payload || jsonb_build_object('session_id', s.id)
FROM reading_sessions s
WHERE a.type = 'reading_session'
  AND NOT (a.payload ? 'session_id')
  AND s.user_id = a.author_id
  AND s.book_id::text = a.payload->>'book_id'
  AND COALESCE(s.start_page::text, '') = COALESCE(a.payload->>'start_page', '')
  AND COALESCE(s.end_page::text, '')   = COALESCE(a.payload->>'end_page', '')
  AND s.end_time IS NOT NULL
  AND ABS(EXTRACT(EPOCH FROM (s.end_time - a.created_at))) < 120;

-- ─── 2.5. Cleanup post-backfill par session_id ──────────────────────────
-- Le cleanup step 1 ne couvrait que les doublons exacts (mêmes book_id +
-- start/end_page). Si une session a été terminée 2 fois avec un end_page
-- différent entre les 2 (resume + lecture supplémentaire avant 2ème end),
-- step 1 les a laissés passer. Mais après backfill, l'UPDATE a pu assigner
-- le même session_id aux 2 activités → l'index unique partiel échouerait.
-- On dédoublonne ici par (author_id, session_id) pour garantir l'unicité.

WITH ranked_by_session AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY author_id, payload->>'session_id'
           ORDER BY id
         ) AS rn
  FROM activities
  WHERE type = 'reading_session'
    AND payload ? 'session_id'
)
DELETE FROM activities
WHERE id IN (SELECT id FROM ranked_by_session WHERE rn > 1);

-- ─── 3. Index unique partiel ────────────────────────────────────────────
-- Garde-fou final : impossible d'avoir deux activités reading_session
-- portant le même session_id pour un même author_id. Le WHERE rend l'index
-- partiel — les anciennes lignes sans session_id ne sont pas couvertes
-- (compatibilité ascendante).

CREATE UNIQUE INDEX IF NOT EXISTS uq_activities_reading_session_session_id
  ON activities (author_id, ((payload->>'session_id')))
  WHERE type = 'reading_session' AND payload ? 'session_id';

-- ─── 4. Trigger refait ──────────────────────────────────────────────────
-- Changements vs 20260512_auto_activity_on_session_end :
--   • session_id ajouté au payload
--   • dédup par session_id (au lieu de la fenêtre temporelle ±2 min)
--   • EXCEPTION WHEN unique_violation pour neutraliser une race condition
--     extrêmement improbable (deux triggers concurrents sur la même session)

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
  -- Ne fire que quand end_time passe de NULL à non-NULL
  IF OLD.end_time IS NOT NULL OR NEW.end_time IS NULL THEN
    RETURN NEW;
  END IF;

  -- book_id doit être un BIGINT (FK vers books)
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

  -- Dédup principal : une activité existe déjà pour cette session ?
  -- (cas : session resumée puis re-terminée → le trigger refire mais on
  -- ne veut pas créer de doublon)
  IF EXISTS (
    SELECT 1 FROM activities
    WHERE author_id = NEW.user_id
      AND type = 'reading_session'
      AND payload->>'session_id' = NEW.id::text
  ) THEN
    RETURN NEW;
  END IF;

  -- Insertion. session_id est stocké dans le payload pour le dédup futur
  -- et pour l'index unique partiel.
  -- Le BEGIN/EXCEPTION protège contre une race condition extrêmement
  -- improbable (deux triggers concurrents sur la même session) — l'index
  -- unique partiel sert de garde-fou.
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
  EXCEPTION WHEN unique_violation THEN
    -- Race : une activité pour cette session a été créée entre le EXISTS
    -- et l'INSERT. On ignore silencieusement.
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- Le trigger lui-même est inchangé (créé en 20260512), CREATE OR REPLACE
-- FUNCTION suffit à mettre à jour son comportement.

COMMIT;

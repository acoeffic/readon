-- =====================================================
-- Migration: relâcher la contrainte de check sur reading_sessions
-- pour autoriser end_page == start_page (session 0 page lue).
--
-- Contexte
-- --------
-- La contrainte historique (anonyme, créée inline dans le CREATE TABLE
-- d'origine, nommée par défaut `reading_sessions_check` par Postgres)
-- impose `end_page > start_page` strict. Conséquence : un utilisateur
-- qui démarre une session puis veut la terminer sans avoir progressé
-- d'au moins une page entière reçoit une erreur 23514 brute :
--
--   new row for relation "reading_sessions" violates check
--   constraint "reading_sessions_check"
--
-- C'est un cas d'usage légitime (on a lu un bout de page, on ferme la
-- session). On relâche à `end_page >= start_page` et on renomme la
-- contrainte pour qu'elle soit identifiable dans les futures migrations.
--
-- Sécurité
-- --------
-- Le check `end_page IS NULL` reste autorisé (sessions actives en cours).
-- =====================================================

ALTER TABLE reading_sessions
  DROP CONSTRAINT IF EXISTS reading_sessions_check;

ALTER TABLE reading_sessions
  ADD CONSTRAINT chk_reading_sessions_end_page_gte_start
  CHECK (end_page IS NULL OR end_page >= start_page);

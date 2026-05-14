-- ============================================================================
-- MIGRATION: Plafond de durée souple — sessions > 6h
-- ============================================================================
-- Détecte les sessions de lecture anormalement longues (> 6 heures), les flague
-- via `is_too_long`, et les exclut automatiquement des stats de badges en
-- ré-utilisant la plomberie existante `is_too_fast IS NOT TRUE` déjà présente
-- dans toutes les RPCs (get_all_user_badges, check_and_award_badges, …).
--
-- Design note — pourquoi on set aussi `is_too_fast = TRUE` :
-- Les RPCs de badges filtrent déjà `AND (is_too_fast IS NOT TRUE)` partout.
-- Plutôt que de ré-éditer ~500 lignes de plpgsql pour ajouter une 2ᵉ clause
-- `AND (is_too_long IS NOT TRUE)` à chaque endroit, on active le flag existant
-- sur les sessions trop longues. La raison est conservée dans `is_too_long`
-- pour audit / UX (on peut afficher « exclue car durée anormale »).
-- `secret_flash` reste intact : il se base sur la table `speed_violations`,
-- qui n'est renseignée que par `check_and_award_secret_badges` sur réelle
-- détection pages/min > 3.
--
-- Seuil : 6 heures. Suffisant pour les marathons de lecture légitimes,
-- attrape les oublis de fin de session + les bugs de Live Activity.
-- ============================================================================

-- ============================================================================
-- 1. COLONNE is_too_long
-- ============================================================================

ALTER TABLE reading_sessions
ADD COLUMN IF NOT EXISTS is_too_long BOOLEAN DEFAULT FALSE;

-- Index partiel — seules les sessions flagguées (très minoritaires) sont
-- indexées, pour consultation d'audit / UI future.
CREATE INDEX IF NOT EXISTS idx_reading_sessions_too_long
  ON reading_sessions(user_id, is_too_long)
  WHERE is_too_long = TRUE;

-- ============================================================================
-- 2. TRIGGER — flag automatique à l'insertion/update
-- ============================================================================

-- Seuil : 6 heures = 21600 secondes.
CREATE OR REPLACE FUNCTION flag_too_long_session()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Re-calcule à chaque UPDATE : si la session est éditée pour être raccourcie,
  -- `is_too_long` repasse à FALSE. On ne reset PAS `is_too_fast` en revanche,
  -- car il peut avoir été latché par la détection de vitesse — le trigger ne
  -- fait que latcher UP, jamais DOWN.
  IF NEW.end_time IS NOT NULL AND NEW.start_time IS NOT NULL THEN
    NEW.is_too_long := EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time)) > 21600;
  ELSE
    NEW.is_too_long := FALSE;
  END IF;

  IF NEW.is_too_long THEN
    NEW.is_too_fast := TRUE;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_flag_too_long_session ON reading_sessions;

CREATE TRIGGER trg_flag_too_long_session
  BEFORE INSERT OR UPDATE OF end_time, start_time ON reading_sessions
  FOR EACH ROW
  EXECUTE FUNCTION flag_too_long_session();

-- ============================================================================
-- 3. BACKFILL — flag les sessions historiques > 6h
-- ============================================================================

UPDATE reading_sessions
SET is_too_long = TRUE,
    is_too_fast = TRUE
WHERE end_time IS NOT NULL
  AND start_time IS NOT NULL
  AND is_too_long IS NOT TRUE
  AND EXTRACT(EPOCH FROM (end_time - start_time)) > 21600;

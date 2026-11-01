-- ============================================================================
-- Sessions oubliées (chrono laissé tournant) : correction automatique
-- ============================================================================
-- Avant : une session de plus de 6 h était seulement FLAGGÉE (is_too_long +
-- is_too_fast) -> exclue des badges/flow, mais sa durée brute (ex. 33,9 h)
-- restait en base et dans tous les totaux de temps lu.
--
-- Maintenant : à la fermeture d'une session NON manuelle de plus de 6 h, on
-- ramène end_time à start_time + durée estimée (pages lues x 1,5 min, bornée
-- entre 1 min et 3 h). La durée d'origine est conservée dans
-- duration_capped_from_seconds (audit). La session redevient plausible : elle
-- compte normalement (pages, badges, flow) au lieu d'être exclue.
-- Les sessions manuelles (is_manual) gardent l'ancien comportement : flaggées
-- au-delà de 6 h, jamais modifiées (c'est l'utilisateur qui a saisi la durée).
-- ============================================================================

ALTER TABLE reading_sessions
  ADD COLUMN IF NOT EXISTS duration_capped_from_seconds integer;

CREATE OR REPLACE FUNCTION flag_too_long_session()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_secs   numeric;
  v_pages  integer;
  v_est    integer;
BEGIN
  IF NEW.end_time IS NOT NULL AND NEW.start_time IS NOT NULL THEN
    v_secs := EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time));

    -- Correction auto : session temps réel, fermée, > 6 h.
    IF v_secs > 21600 AND NOT COALESCE(NEW.is_manual, FALSE) THEN
      v_pages := GREATEST(COALESCE(NEW.end_page, NEW.start_page) - NEW.start_page, 0);
      v_est   := LEAST(10800, GREATEST(60, ROUND(v_pages * 1.5 * 60)::int));
      -- On garde la durée d'origine la première fois seulement.
      NEW.duration_capped_from_seconds :=
        COALESCE(NEW.duration_capped_from_seconds, ROUND(v_secs)::int);
      NEW.end_time := NEW.start_time + make_interval(secs => v_est);
      v_secs := v_est;
    END IF;

    NEW.is_too_long := v_secs > 21600;
  ELSE
    NEW.is_too_long := FALSE;
  END IF;

  -- Latch UP uniquement (jamais DOWN) : voir 20260514_long_session_cap.sql.
  IF NEW.is_too_long THEN
    NEW.is_too_fast := TRUE;
  END IF;

  RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Backfill des sessions historiques non manuelles > 6 h (8 en prod au 11/10).
-- Triggers désactivés le temps de la transaction pour ne pas rejouer feed,
-- badges ni récompenses de parrainage.
-- ----------------------------------------------------------------------------
SET LOCAL session_replication_role = replica;

UPDATE reading_sessions rs
SET duration_capped_from_seconds = ROUND(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)))::int,
    end_time = rs.start_time + make_interval(
      secs => LEAST(10800, GREATEST(60,
        ROUND(GREATEST(COALESCE(rs.end_page, rs.start_page) - rs.start_page, 0) * 1.5 * 60)::int))),
    is_too_long = FALSE,
    -- is_too_fast n'était latché que par is_too_long, sauf violation de vitesse.
    is_too_fast = EXISTS (SELECT 1 FROM speed_violations v WHERE v.session_id = rs.id)
WHERE rs.end_time IS NOT NULL
  AND rs.start_time IS NOT NULL
  AND rs.is_too_long IS TRUE
  AND NOT COALESCE(rs.is_manual, FALSE)
  AND rs.duration_capped_from_seconds IS NULL;

SET LOCAL session_replication_role = origin;

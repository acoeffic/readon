-- ============================================================================
-- FIX: Corriger les end_time stockes en heure locale au lieu de UTC
-- ============================================================================
-- Bug: startSession utilisait .toUtc() mais endSession non.
-- Resultat: start_time est en UTC, end_time est en heure locale (Europe/Paris).
-- Cela ajoutait ~1h (UTC+1 hiver) ou ~2h (UTC+2 ete) a la duree des sessions.
--
-- Cette migration reinterprete end_time comme heure Europe/Paris au lieu de UTC.
-- La clause >= start_time protege les sessions deja correctes (ex: simulateur UTC).
-- ATTENTION: a executer UNE SEULE FOIS, avant de deployer le fix cote client.
-- ============================================================================

UPDATE reading_sessions
SET end_time = (end_time AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris'
WHERE end_time IS NOT NULL
  AND (end_time AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris' >= start_time;

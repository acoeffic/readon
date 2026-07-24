-- Ajoute un flag "session saisie manuellement a posteriori" sur
-- reading_sessions (feature "Ajouter une lecture passée").
-- Une session is_manual dont la date de end_time diffère de created_at est
-- considérée antidatée : elle compte pour les stats/feed/défis mais est
-- exclue du calcul de la flamme (logique côté client, FlowService).

ALTER TABLE reading_sessions
  ADD COLUMN IF NOT EXISTS is_manual BOOLEAN NOT NULL DEFAULT FALSE;

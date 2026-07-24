-- Re-engagement (win-back) tracking
-- Permet à l'edge function send-reengagement de n'envoyer qu'une relance
-- par palier d'inactivité (3, 7, 14 jours) et de ne jamais spammer.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS reengagement_last_bucket SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reengagement_last_sent_at TIMESTAMPTZ;

COMMENT ON COLUMN profiles.reengagement_last_bucket IS
  'Dernier palier de relance d''inactivité envoyé (0=aucun, 3, 7, 14). Réinitialisé à 0 quand l''utilisateur redevient actif.';
COMMENT ON COLUMN profiles.reengagement_last_sent_at IS
  'Horodatage de la dernière notification de re-engagement envoyée.';

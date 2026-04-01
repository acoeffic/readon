-- Migration pour ajouter le support des notifications FCM

-- Ajouter les colonnes pour les notifications dans la table profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS notification_reminder_time TEXT DEFAULT '20:00';

-- Créer un index sur fcm_token pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON profiles(fcm_token) WHERE fcm_token IS NOT NULL;

-- Créer un index sur notifications_enabled pour les requêtes de batch
CREATE INDEX IF NOT EXISTS idx_profiles_notifications_enabled ON profiles(notifications_enabled) WHERE notifications_enabled = true;

-- Commentaires pour documenter les colonnes
COMMENT ON COLUMN profiles.fcm_token IS 'Firebase Cloud Messaging token pour les notifications push';
COMMENT ON COLUMN profiles.notifications_enabled IS 'Indique si l''utilisateur a activé les notifications de rappel de streak';
COMMENT ON COLUMN profiles.notification_reminder_time IS 'Heure de rappel quotidien au format HH:mm (ex: 20:00)';

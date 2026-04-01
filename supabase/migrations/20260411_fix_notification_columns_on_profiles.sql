-- Fix: ajouter les colonnes de notifications sur profiles
-- (la migration originale les avait créées sur 'users' par erreur)

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS notification_reminder_time TEXT DEFAULT '20:00',
ADD COLUMN IF NOT EXISTS notify_friend_requests BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS notify_friend_requests_email BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON profiles(fcm_token) WHERE fcm_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_notifications_enabled ON profiles(notifications_enabled) WHERE notifications_enabled = true;

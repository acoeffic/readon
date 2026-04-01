-- Add timezone column to profiles for correct push notification scheduling
-- The notification_reminder_time is stored in local time; we need the timezone
-- to convert it to UTC server-side.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'Europe/Paris';

COMMENT ON COLUMN public.profiles.timezone IS 'IANA timezone (e.g. Europe/Paris) used to convert notification_reminder_time to UTC';

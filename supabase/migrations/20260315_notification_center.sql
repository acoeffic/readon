-- Add notification preference columns to profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notify_friend_requests BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_friend_requests_email BOOLEAN NOT NULL DEFAULT true;

-- Trigger function: call Edge Function to send email on friend request
CREATE OR REPLACE FUNCTION send_friend_request_email()
RETURNS TRIGGER AS $$
DECLARE
  recipient RECORD;
  sender RECORD;
  payload JSONB;
BEGIN
  IF NEW.status = 'pending' THEN
    -- Check if the recipient has email notifications enabled
    SELECT id, display_name, email, notify_friend_requests_email
      INTO recipient
      FROM profiles
      WHERE id = NEW.addressee_id;

    IF recipient IS NULL OR NOT recipient.notify_friend_requests_email THEN
      RETURN NEW;
    END IF;

    -- Get sender info
    SELECT display_name INTO sender FROM profiles WHERE id = NEW.requester_id;

    -- Build payload
    payload := jsonb_build_object(
      'to_email', recipient.email,
      'to_name', COALESCE(recipient.display_name, 'Lecteur'),
      'from_name', COALESCE(sender.display_name, 'Un utilisateur')
    );

    -- Call edge function via pg_net
    PERFORM net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/send-friend-request-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := payload
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger (runs after the existing notification trigger)
DROP TRIGGER IF EXISTS trigger_friend_request_email ON friends;
CREATE TRIGGER trigger_friend_request_email
  AFTER INSERT ON friends
  FOR EACH ROW
  EXECUTE FUNCTION send_friend_request_email();

-- Ensure email column exists in profiles (from auth.users)
-- If profiles.email doesn't exist, add it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'email'
  ) THEN
    ALTER TABLE profiles ADD COLUMN email TEXT;
    -- Backfill from auth.users
    UPDATE profiles p SET email = u.email FROM auth.users u WHERE u.id = p.id;
  END IF;
END $$;

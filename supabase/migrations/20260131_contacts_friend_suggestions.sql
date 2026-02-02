-- Migration: Contacts-based friend suggestions
-- Adds email/phone hashing for privacy-preserving contact matching

-- Ensure pgcrypto is available (in extensions schema on Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Add columns to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS email_hash TEXT,
ADD COLUMN IF NOT EXISTS phone_hash TEXT,
ADD COLUMN IF NOT EXISTS has_completed_first_session BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS has_seen_contacts_prompt BOOLEAN DEFAULT FALSE;

-- Indexes for fast hash lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email_hash ON profiles(email_hash);
CREATE INDEX IF NOT EXISTS idx_profiles_phone_hash ON profiles(phone_hash);

-- Backfill email_hash for existing users
UPDATE profiles
SET email_hash = encode(extensions.digest(lower(trim(email)), 'sha256'), 'hex')
WHERE email IS NOT NULL AND email_hash IS NULL;

-- Backfill has_completed_first_session for users with completed sessions
UPDATE profiles
SET has_completed_first_session = TRUE
WHERE id IN (
  SELECT DISTINCT user_id FROM reading_sessions WHERE end_time IS NOT NULL
);

-- Trigger to auto-hash email on insert/update
CREATE OR REPLACE FUNCTION hash_profile_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, extensions
AS $$
BEGIN
  IF NEW.email IS NOT NULL AND (OLD IS NULL OR OLD.email IS DISTINCT FROM NEW.email) THEN
    NEW.email_hash := encode(extensions.digest(lower(trim(NEW.email)), 'sha256'), 'hex');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hash_profile_email ON profiles;
CREATE TRIGGER trg_hash_profile_email
  BEFORE INSERT OR UPDATE OF email ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION hash_profile_email();

-- RPC function: find contacts matches from hashed emails/phones
CREATE OR REPLACE FUNCTION find_contacts_matches(
  p_hashes TEXT[]
)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_user_id UUID;
BEGIN
  v_current_user_id := auth.uid();

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'display_name', p.display_name,
    'email', p.email,
    'avatar_url', p.avatar_url,
    'is_profile_private', COALESCE(p.is_profile_private, FALSE)
  )
  FROM profiles p
  WHERE (p.email_hash = ANY(p_hashes) OR p.phone_hash = ANY(p_hashes))
    AND p.id != v_current_user_id
    AND p.id NOT IN (
      SELECT CASE
        WHEN f.requester_id = v_current_user_id THEN f.addressee_id
        ELSE f.requester_id
      END
      FROM friends f
      WHERE f.requester_id = v_current_user_id
         OR f.addressee_id = v_current_user_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION find_contacts_matches(TEXT[]) TO authenticated;

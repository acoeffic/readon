-- Auto-modération des display_name.
-- Même pattern que `20260524000002_auto_moderate_avatars.sql`.
--
-- 1. Colonnes de tracking sur profiles
-- 2. Trigger BEFORE INSERT/UPDATE OF display_name → pg_net vers edge
--    function `moderate-display-name`
-- 3. L'edge function classe le pseudo via OpenAI omni-moderation-latest.
--    Si rejeté → reverte au display_name précédent (ou NULL si signup).

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS display_name_moderation_status TEXT NOT NULL DEFAULT 'approved'
    CHECK (display_name_moderation_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS display_name_rejected_reason TEXT;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS display_name_moderated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_display_name_moderation_pending
  ON profiles (display_name_moderation_status, display_name_moderated_at)
  WHERE display_name_moderation_status = 'pending';

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION trigger_moderate_display_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_supabase_url      CONSTANT text := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  v_service_role_key  text;
  v_old_value         text;
BEGIN
  -- Sortir si le pseudo n'a pas changé OU est null/vide.
  IF NEW.display_name IS NULL OR trim(NEW.display_name) = '' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.display_name IS NOT DISTINCT FROM NEW.display_name THEN
    RETURN NEW;
  END IF;

  -- On stocke le pending sur la nouvelle valeur. La précédente est
  -- passée à l'edge function pour permettre une rollback propre.
  NEW.display_name_moderation_status := 'pending';
  NEW.display_name_rejected_reason := NULL;
  NEW.display_name_moderated_at := NULL;

  v_old_value := CASE WHEN TG_OP = 'UPDATE' THEN OLD.display_name ELSE NULL END;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';

  IF v_service_role_key IS NULL THEN
    RAISE WARNING 'trigger_moderate_display_name: vault secret "service_role_key" missing';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/moderate-display-name',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'user_id', NEW.id,
      'new_value', NEW.display_name,
      'old_value', v_old_value
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'trigger_moderate_display_name failed for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_moderate_display_name_before_update ON profiles;
CREATE TRIGGER trg_moderate_display_name_before_update
  BEFORE UPDATE OF display_name ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION trigger_moderate_display_name();

DROP TRIGGER IF EXISTS trg_moderate_display_name_before_insert ON profiles;
CREATE TRIGGER trg_moderate_display_name_before_insert
  BEFORE INSERT ON profiles
  FOR EACH ROW
  WHEN (NEW.display_name IS NOT NULL AND trim(NEW.display_name) <> '')
  EXECUTE FUNCTION trigger_moderate_display_name();

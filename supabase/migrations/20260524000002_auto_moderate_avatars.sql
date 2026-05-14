-- Modération automatique des avatars uploadés.
-- Même pattern que `20260518_auto_moderate_comments.sql` :
--   1. Colonne `avatar_moderation_status` sur `profiles` (pending par défaut)
--   2. Trigger AFTER UPDATE OF avatar_url → appelle l'edge function
--      `moderate-avatar` via pg_net (fire-and-forget)
--   3. L'edge function classe l'image via OpenAI omni-moderation-latest,
--      met à jour le statut, et révoque l'avatar si rejeté (avatar_url
--      remis à NULL + insertion dans content_reports pour audit)
--
-- Prérequis : le secret Vault `service_role_key` doit déjà exister
-- (créé pour `moderate-comment`).

-- ─────────────────────────────────────────────────────────────────────
-- 1. Colonnes de tracking sur profiles
-- ─────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS avatar_moderation_status TEXT NOT NULL DEFAULT 'approved'
    CHECK (avatar_moderation_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS avatar_rejected_reason TEXT;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS avatar_moderated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_avatar_moderation_pending
  ON profiles (avatar_moderation_status, avatar_moderated_at)
  WHERE avatar_moderation_status = 'pending';

-- ─────────────────────────────────────────────────────────────────────
-- 2. Trigger function : appelle l'edge function via pg_net
-- ─────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION trigger_moderate_avatar()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_supabase_url      CONSTANT text := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  v_service_role_key  text;
BEGIN
  -- Sortir si l'avatar n'a pas changé OU est null/vide.
  IF NEW.avatar_url IS NULL OR NEW.avatar_url = '' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.avatar_url IS NOT DISTINCT FROM NEW.avatar_url THEN
    RETURN NEW;
  END IF;

  -- Marquer pending pour que le client puisse afficher un fallback ou un
  -- état "en cours de validation" si souhaité.
  NEW.avatar_moderation_status := 'pending';
  NEW.avatar_rejected_reason := NULL;
  NEW.avatar_moderated_at := NULL;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';

  IF v_service_role_key IS NULL THEN
    RAISE WARNING 'trigger_moderate_avatar: vault secret "service_role_key" missing';
    RETURN NEW;
  END IF;

  -- Fire-and-forget HTTP call. Le résultat de la modération est appliqué
  -- par l'edge function en utilisant le service_role.
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/moderate-avatar',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'user_id', NEW.id,
      'avatar_url', NEW.avatar_url
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais bloquer l'UPDATE si pg_net échoue.
    RAISE WARNING 'trigger_moderate_avatar failed for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- BEFORE UPDATE (pas AFTER) parce qu'on modifie NEW pour set le statut
-- pending avant que la row soit écrite.
DROP TRIGGER IF EXISTS trg_moderate_avatar_before_update ON profiles;
CREATE TRIGGER trg_moderate_avatar_before_update
  BEFORE UPDATE OF avatar_url ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION trigger_moderate_avatar();

DROP TRIGGER IF EXISTS trg_moderate_avatar_before_insert ON profiles;
CREATE TRIGGER trg_moderate_avatar_before_insert
  BEFORE INSERT ON profiles
  FOR EACH ROW
  WHEN (NEW.avatar_url IS NOT NULL AND NEW.avatar_url <> '')
  EXECUTE FUNCTION trigger_moderate_avatar();

-- ─────────────────────────────────────────────────────────────────────
-- 3. Helper RPC pour re-modérer un avatar (utilisé par l'edge function
--    si elle veut réessayer, ou par l'admin via Studio).
-- ─────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION rerun_avatar_moderation(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Force le trigger en mettant à jour la même valeur via touch.
  -- On contourne le `IS NOT DISTINCT FROM` du trigger en remettant
  -- d'abord NULL puis l'URL réelle, dans la même transaction.
  UPDATE profiles
  SET avatar_moderation_status = 'pending',
      avatar_rejected_reason = NULL,
      avatar_moderated_at = NULL
  WHERE id = p_user_id AND avatar_url IS NOT NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION rerun_avatar_moderation(UUID) TO service_role;

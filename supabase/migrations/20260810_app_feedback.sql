-- Feedback in-app des utilisateurs (bêta et au-delà).
--
-- Contexte 10/08/2026 : un bêta-testeur n'a pas trouvé comment faire un
-- retour depuis l'app. On ajoute un canal direct : table `app_feedback`
-- (write-only côté client) + notification email admin à chaque INSERT.
--
-- Pattern identique à 20260809_report_email_notifications.sql :
-- trigger → pg_net → edge function `send-feedback-email` (Resend),
-- clé service_role lue depuis Vault. Fire-and-forget, ne bloque
-- jamais l'INSERT.

CREATE TABLE IF NOT EXISTS app_feedback (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message     text NOT NULL,
  app_version text,
  platform    text,
  locale      text,
  status      text NOT NULL DEFAULT 'new',
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_feedback_message_len
    CHECK (char_length(btrim(message)) BETWEEN 1 AND 2000),
  CONSTRAINT app_feedback_meta_len
    CHECK (char_length(coalesce(app_version, '')) <= 50
       AND char_length(coalesce(platform, '')) <= 50
       AND char_length(coalesce(locale, '')) <= 20),
  CONSTRAINT app_feedback_status_check
    CHECK (status IN ('new', 'reviewed', 'done'))
);

ALTER TABLE app_feedback ENABLE ROW LEVEL SECURITY;

-- Write-only pour les users : INSERT de leurs propres lignes, pas de
-- SELECT/UPDATE/DELETE (boîte de réception admin, traitée via Studio).
-- Grants explicites (cf. durcissement RLS du 22/07/2026) : rien pour anon.
REVOKE ALL ON app_feedback FROM anon, authenticated;
GRANT INSERT (user_id, message, app_version, platform, locale)
  ON app_feedback TO authenticated;

DROP POLICY IF EXISTS app_feedback_insert_own ON app_feedback;
CREATE POLICY app_feedback_insert_own ON app_feedback
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ── Notification email admin ────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION notify_feedback_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_supabase_url      CONSTANT text := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  v_service_role_key  text;
  v_user_name         text;
  v_user_email        text;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';

  IF v_service_role_key IS NULL THEN
    RAISE WARNING 'notify_feedback_email: vault secret "service_role_key" missing';
    RETURN NEW;
  END IF;

  SELECT COALESCE(display_name, 'Inconnu') INTO v_user_name
  FROM profiles WHERE id = NEW.user_id;

  SELECT email INTO v_user_email
  FROM auth.users WHERE id = NEW.user_id;

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send-feedback-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'feedback_id', NEW.id,
      'message', NEW.message,
      'user_name', v_user_name,
      'user_email', v_user_email,
      'app_version', NEW.app_version,
      'platform', NEW.platform,
      'locale', NEW.locale,
      'created_at', to_char(NEW.created_at AT TIME ZONE 'Europe/Paris',
                            'DD/MM/YYYY HH24:MI')
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais bloquer l'INSERT du feedback si la notif échoue.
    RAISE WARNING 'notify_feedback_email failed for feedback %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_feedback_email_after_insert ON app_feedback;
CREATE TRIGGER trg_feedback_email_after_insert
  AFTER INSERT ON app_feedback
  FOR EACH ROW
  EXECUTE FUNCTION notify_feedback_email();

-- Notification email admin à chaque nouveau signalement.
--
-- Problème constaté le 09/08/2026 : les lignes de `content_reports`
-- (signalements manuels + auto-rejets avatar/display-name) n'étaient
-- notifiées nulle part — un report de spam du 15/06 est resté invisible
-- pendant presque 2 mois. Les guidelines Apple §1.2 exigent un
-- traitement rapide des signalements UGC.
--
-- Pattern identique à 20260534_comment_email_notifications.sql :
-- trigger → pg_net → edge function `send-report-email` (Resend),
-- clé service_role lue depuis Vault. Fire-and-forget, ne bloque
-- jamais l'INSERT.

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION notify_report_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_supabase_url      CONSTANT text := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  v_service_role_key  text;
  v_reporter_name     text;
  v_target_user_name  text;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key';

  IF v_service_role_key IS NULL THEN
    RAISE WARNING 'notify_report_email: vault secret "service_role_key" missing';
    RETURN NEW;
  END IF;

  SELECT COALESCE(display_name, 'Inconnu') INTO v_reporter_name
  FROM profiles WHERE id = NEW.reporter_id;

  IF NEW.target_user_id IS NOT NULL THEN
    SELECT COALESCE(display_name, 'Inconnu') INTO v_target_user_name
    FROM profiles WHERE id = NEW.target_user_id;
  END IF;

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send-report-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'report_id', NEW.id,
      'target_type', NEW.target_type,
      'target_id', NEW.target_id,
      'reason', NEW.reason,
      'status', NEW.status,
      'details', NEW.details,
      'reporter_name', v_reporter_name,
      'target_user_name', v_target_user_name,
      'created_at', to_char(NEW.created_at AT TIME ZONE 'Europe/Paris',
                            'DD/MM/YYYY HH24:MI')
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Ne jamais bloquer l'INSERT du signalement si la notif échoue.
    RAISE WARNING 'notify_report_email failed for report %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_report_email_after_insert ON content_reports;
CREATE TRIGGER trg_report_email_after_insert
  AFTER INSERT ON content_reports
  FOR EACH ROW
  EXECUTE FUNCTION notify_report_email();

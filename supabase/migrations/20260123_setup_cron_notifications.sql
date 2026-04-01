-- Configuration du cron job pour envoyer les rappels de streak
-- Tourne toutes les 15 minutes ; l'edge function filtre par notification_reminder_time

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Supprimer le job s'il existe déjà (permet de re-run la migration)
SELECT cron.unschedule('send-streak-reminders-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'send-streak-reminders-daily'
);
SELECT cron.unschedule('send-streak-reminders') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'send-streak-reminders'
);

-- Toutes les 15 minutes, appeler l'edge function
-- On utilise service_role_key (déjà configuré et utilisé par les autres triggers)
SELECT cron.schedule(
  'send-streak-reminders',
  '*/15 * * * *',
  $$
  SELECT
    net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/send-streak-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

COMMENT ON EXTENSION pg_cron IS 'Planificateur de tâches pour PostgreSQL';

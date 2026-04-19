-- Nightly cover refresh via pg_cron.
-- Calls the refresh-covers edge function once a day at 03:00 UTC.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Remove existing job if re-running migration
SELECT cron.unschedule('refresh-covers-nightly') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'refresh-covers-nightly'
);

-- Schedule: every day at 03:00 UTC
SELECT cron.schedule(
  'refresh-covers-nightly',
  '0 3 * * *',
  $$
  SELECT
    net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/refresh-covers',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

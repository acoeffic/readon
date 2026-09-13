-- Le job pg_cron 'render-monthly-wrapped' échouait chaque 1er du mois avec
-- "unrecognized configuration parameter app.settings.service_role_key"
-- (paramètre jamais défini sur cette base) : la vidéo Wrapped n'a jamais été
-- pré-générée (constaté dans cron.job_run_details, échecs 01/07 et 01/08).
-- On passe par vault.decrypted_secrets, comme sync-literary-prizes.
-- Appliqué en prod via MCP le 02/08/2026 ; idempotent.

SELECT cron.unschedule('render-monthly-wrapped') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'render-monthly-wrapped'
);

SELECT cron.schedule(
  'render-monthly-wrapped',
  '0 2 1 * *',
  $$
  SELECT
    net.http_post(
      url := 'https://readon-sync-production-f130.up.railway.app/api/wrapped/monthly/render-all',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

-- Cron job : pré-générer les vidéos monthly wrapped le 1er de chaque mois à 2h du matin UTC.
-- Appelle l'endpoint render-all de readon-sync qui génère la vidéo pour tous
-- les utilisateurs ayant eu au moins une session le mois précédent.
-- Les vidéos sont prêtes avant la notification locale de 9h.

-- Supprimer le job s'il existe déjà (permet de re-run la migration)
SELECT cron.unschedule('render-monthly-wrapped') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'render-monthly-wrapped'
);

-- Le 1er de chaque mois à 2h UTC
SELECT cron.schedule(
  'render-monthly-wrapped',
  '0 2 1 * *',
  $$
  SELECT
    net.http_post(
      url := 'https://readon-sync-production-f130.up.railway.app/api/wrapped/monthly/render-all',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

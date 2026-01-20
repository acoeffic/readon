-- Configuration du cron job pour envoyer les notifications de streak quotidiennement

-- Activer l'extension pg_cron si ce n'est pas déjà fait
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Activer l'extension http pour faire des requêtes HTTP
CREATE EXTENSION IF NOT EXISTS http;

-- Supprimer le job s'il existe déjà (pour permettre la réexécution de la migration)
SELECT cron.unschedule('send-streak-reminders-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'send-streak-reminders-daily'
);

-- Créer le cron job pour exécuter la fonction Edge tous les jours à 20h UTC
-- Note: Vous devrez remplacer YOUR_PROJECT_REF et YOUR_SERVICE_ROLE_KEY avec vos vraies valeurs
-- Il est recommandé de faire cela manuellement via la console Supabase ou un script de déploiement

-- Exemple de cron job (à configurer manuellement):
/*
SELECT cron.schedule(
  'send-streak-reminders-daily',
  '0 20 * * *', -- Tous les jours à 20h UTC
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-streak-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
*/

-- Note importante sur les fuseaux horaires:
-- Le cron job s'exécute en UTC. Pour une notification à 20h heure locale:
-- - France (UTC+1): 19h UTC (18h en hiver UTC+0)
-- - Amérique/New York (UTC-5): 01h UTC le lendemain
-- Ajustez l'heure selon votre fuseau horaire cible

COMMENT ON EXTENSION pg_cron IS 'Planificateur de tâches pour PostgreSQL';

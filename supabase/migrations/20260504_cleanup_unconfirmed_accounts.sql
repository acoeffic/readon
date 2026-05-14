-- Cron job : nettoyage des comptes non confirmés.
-- Supprime auth.users.email_confirmed_at IS NULL âgés de plus de 7 jours.
-- Les FK ON DELETE CASCADE de public.* prennent soin du reste (profiles,
-- reading_goals, etc.).
--
-- Pourquoi 7 jours et pas 24 h : laisser une marge confortable aux users
-- qui voient l'email après quelques jours sans casser leur (ré)inscription.

-- Fonction de cleanup, exécutée par pg_cron en tant que superuser.
CREATE OR REPLACE FUNCTION public.cleanup_unconfirmed_accounts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_deleted integer;
BEGIN
  WITH del AS (
    DELETE FROM auth.users
    WHERE email_confirmed_at IS NULL
      AND created_at < now() - interval '7 days'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted FROM del;

  RAISE NOTICE 'cleanup_unconfirmed_accounts: deleted % rows', v_deleted;
  RETURN v_deleted;
END;
$$;

-- Drop le job si re-run de la migration
SELECT cron.unschedule('cleanup-unconfirmed-accounts') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'cleanup-unconfirmed-accounts'
);

-- Tous les jours à 3h UTC (creux de trafic)
SELECT cron.schedule(
  'cleanup-unconfirmed-accounts',
  '0 3 * * *',
  $$ SELECT public.cleanup_unconfirmed_accounts(); $$
);

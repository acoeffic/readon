-- Appliquée en prod le 22/07/2026 (migration `revoke_anon_security_definer_functions`).
--
-- Advisor anon_security_definer_function_executable (90 fonctions) :
-- anon n'appelle jamais de RPC dans LexDay (tout est derrière le login).
-- On fige les grants explicites (authenticated/service_role) puis on
-- révoque PUBLIC + anon sur toutes les fonctions SECURITY DEFINER.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS fn,
           has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_ok
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
  LOOP
    -- conserver l'accès app existant (hérité de PUBLIC jusqu'ici)
    IF r.auth_ok THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.fn);
    END IF;
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.fn);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', r.fn);
  END LOOP;
END $$;

-- Jobs internes (cron/triggers) : jamais appelés par l'app ni les Edge
-- Functions → pas d'accès authenticated non plus.
REVOKE EXECUTE ON FUNCTION public._auto_freeze_for_user(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.auto_freeze_all_users() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cleanup_old_feed_items() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cleanup_unconfirmed_accounts() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fan_out_activity() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.check_and_award_all_badges(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_reading_session(uuid, integer, text) FROM authenticated;

-- Les futures fonctions créées par migration n'auront plus l'EXECUTE
-- implicite PUBLIC : toute nouvelle RPC destinée à l'app devra faire un
-- GRANT EXECUTE ... TO authenticated explicite.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

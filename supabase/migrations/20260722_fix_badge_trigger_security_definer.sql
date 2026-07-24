-- Appliquée en prod le 22/07/2026 au soir (migration `fix_badge_trigger_security_definer`).
--
-- Hotfix : le durcissement du 22/07 (revoke authenticated sur
-- check_and_award_all_badges) cassait la fin de session — le trigger
-- trigger_check_all_badges (AFTER sur reading_sessions) n'est pas
-- SECURITY DEFINER et s'exécute donc en tant qu'utilisateur.
-- Fix propre : le trigger devient SECURITY DEFINER (search_path figé),
-- et la fonction interne redevient inaccessible aux clients.

CREATE OR REPLACE FUNCTION public.trigger_check_all_badges()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  -- Appeler la fonction de vérification complète
  PERFORM check_and_award_all_badges(NEW.user_id);
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.check_and_award_all_badges(uuid) FROM authenticated;

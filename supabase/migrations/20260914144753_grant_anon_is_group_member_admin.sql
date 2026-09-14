-- Mode invité : les policies RLS « membres » de reading_groups, group_members,
-- group_challenges, challenge_participants… (rôle {public}) appellent
-- is_group_member() / is_group_admin(), SECURITY DEFINER sans EXECUTE anon
-- depuis 20260722 revoke_anon_security_definer_functions. Postgres vérifie
-- les droits d'exécution à l'initialisation de l'expression : toute requête
-- anon sur ces tables échoue en 42501 « permission denied for function
-- is_group_member », même si une policy anon dédiée (20260516) l'autorise.
-- → depuis le 22/07, un invité ne pouvait ouvrir aucune fiche club
-- (« Groupe introuvable », constaté le 14/09/2026).
--
-- Ces deux fonctions renvoient un booléen d'appartenance ; appelées avec
-- auth.uid() NULL elles renvoient toujours false. Rien de nouveau n'est lu.
GRANT EXECUTE ON FUNCTION public.is_group_member(uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_group_admin(uuid, uuid) TO anon;

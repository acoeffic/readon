-- ============================================================================
-- Durcissement issu de l'audit du 09/10/2026 (AUDIT_BUGS_2026-10-09.md)
-- Non appliquée automatiquement : à relire puis à passer en prod.
-- ============================================================================

-- 1. Fonctions internes : appelées uniquement par d'autres fonctions
--    SECURITY DEFINER (hash_profile_email, find_contacts_matches_v2,
--    check_and_award_*, log_badge_awarded, cron). Aucun usage client/Edge.
--    get_hmac_secret() renvoyait le secret Vault des hash e-mail/téléphone.
REVOKE EXECUTE ON FUNCTION public.get_hmac_secret() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.hmac_hash(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.write_audit_log(text, jsonb, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.refresh_feed_materialized_views() FROM PUBLIC, anon, authenticated;

-- 2. Ancien feed : plus appelé par le client, prend un p_user_id libre et
--    renvoie author_email, sans filtre de blocage.
DROP FUNCTION IF EXISTS public.get_feed(uuid, int, timestamptz);

-- 3. get_user_notifications(p_user_id, …) : IDOR (SECURITY DEFINER, aucun
--    contrôle auth.uid()). On force le filtre sur l'appelant sans changer
--    la signature (le client passe déjà son propre id).
DO $$
DECLARE
  v_def text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef('public.get_user_notifications(uuid,int,int)'::regprocedure)
    INTO v_def;
  v_new := replace(v_def, 'WHERE n.user_id = p_user_id', 'WHERE n.user_id = auth.uid()');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'get_user_notifications: motif "WHERE n.user_id = p_user_id" introuvable, correctif non appliqué';
  END IF;
  EXECUTE v_new;
END $$;

-- Reste à traiter (corps non reproduits ici, voir le rapport) :
--   get_all_user_badges, check_and_award_badges, get_user_groups,
--   get_group_invitations, count_unread_notifications  -> garde auth.uid()
--   get_activity_comments -> filtre user_blocks + retirer author_email
--   streak_freezes / kindle_read_days -> écriture via RPC bornée
--   mv_community_sessions / mv_trending_books -> filtres is_hidden

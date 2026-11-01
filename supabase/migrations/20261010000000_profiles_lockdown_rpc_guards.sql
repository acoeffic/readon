-- Audit 2026-10-09 (partie 2) : fuites confirmées en prod. NON APPLIQUÉE.
-- À appliquer APRÈS déploiement du client (settings_page.dart: .select('avatar_url')).

-- 1) profiles : masquer les colonnes sensibles aux comptes connectés.
--    (le client n'utilise aucune de ces colonnes ; service_role n'est pas affecté)
--    Attention : toute NOUVELLE colonne devra être ajoutée au GRANT pour être lisible.
REVOKE SELECT ON public.profiles FROM authenticated, anon;
GRANT SELECT (
  id, email, display_name, avatar_url, created_at, updated_at,
  is_profile_private, is_premium, premium_until, notification_days,
  onboarding_completed, reading_habit, has_completed_first_session,
  has_seen_contacts_prompt, hide_reading_hours, notion_workspace_name,
  notion_connected_at, fcm_token, notifications_enabled,
  notification_reminder_time, notify_friend_requests,
  notify_friend_requests_email, email_friend_requests, timezone,
  avatar_moderation_status, avatar_rejected_reason, avatar_moderated_at,
  display_name_moderation_status, display_name_rejected_reason,
  display_name_moderated_at, notify_comments_email, referral_code
) ON public.profiles TO authenticated;
REVOKE INSERT ON public.profiles FROM anon;

-- 2) IDOR : p_user_id doit être l'appelant (auth.uid() NULL = service_role / système).
DO $$
DECLARE
  f text;
  d text;
  guard text := E'\nBEGIN\n  IF auth.uid() IS NOT NULL AND p_user_id IS DISTINCT FROM auth.uid() THEN\n    RAISE EXCEPTION ''forbidden'' USING ERRCODE = ''42501'';\n  END IF;\n';
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.count_unread_notifications(uuid)',
    'public.get_group_invitations(uuid)',
    'public.get_user_groups(uuid)',
    'public.check_and_award_badges(uuid)'
  ] LOOP
    d := pg_get_functiondef(f::regprocedure);
    IF position('forbidden' in d) > 0 THEN CONTINUE; END IF;
    d := regexp_replace(d, E'\nBEGIN\n', guard);
    IF position('forbidden' in d) = 0 THEN
      RAISE EXCEPTION 'guard not injected in %', f;
    END IF;
    EXECUTE d;
  END LOOP;
END $$;

ALTER FUNCTION public.get_group_invitations(uuid) SET search_path = public;
ALTER FUNCTION public.get_user_groups(uuid) SET search_path = public;

-- 3) get_activity_comments : ne plus exposer l'e-mail (même signature).
DO $$
DECLARE d text;
BEGIN
  d := pg_get_functiondef('public.get_activity_comments(bigint)'::regprocedure);
  d := replace(d, 'p.email AS author_email', 'NULL::text AS author_email');
  IF position('NULL::text AS author_email' in d) = 0 THEN
    RAISE EXCEPTION 'pattern not found';
  END IF;
  EXECUTE d;
END $$;

-- ROLLBACK profiles : GRANT SELECT ON public.profiles TO authenticated, anon;

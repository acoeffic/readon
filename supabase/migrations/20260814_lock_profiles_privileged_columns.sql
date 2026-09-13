-- Audit 14/08/2026 : `authenticated` avait le GRANT UPDATE au niveau TABLE sur
-- `profiles`, donc sur `is_premium` et `premium_until` — les colonnes que lisent
-- toutes les Edge Functions premium. N'importe quel utilisateur pouvait donc
-- se rendre Premium avec un simple
--   update profiles set is_premium = true where id = auth.uid()
-- (la policy `Users can update own profile` autorise sa propre ligne).
--
-- Postgres ne permet pas de retirer une colonne d'un GRANT posé au niveau table :
-- on révoque donc l'UPDATE global puis on le re-donne colonne par colonne, sur
-- les seules colonnes réellement écrites par les clients (app Flutter + web).

revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;

grant update (
  id,                             -- upsert auth_gate / signup (on conflict)
  email,                          -- idem
  created_at,                     -- idem
  display_name,                   -- réglages + sheet de choix de pseudo
  avatar_url,                     -- upload d'avatar
  fcm_token,                      -- push_notification_service
  is_profile_private,             -- réglages
  hide_reading_hours,             -- réglages
  onboarding_completed,           -- onboarding
  reading_habit,                  -- onboarding
  has_completed_first_session,    -- contacts_service
  has_seen_contacts_prompt,       -- contacts_service
  notifications_enabled,          -- réglages notifications
  notification_days,
  notification_reminder_time,
  notify_friend_requests,
  notify_friend_requests_email,
  notify_comments_email,
  email_friend_requests,
  phone,
  timezone,
  updated_at
) on public.profiles to authenticated;

-- Colonnes volontairement NON accordées (serveur uniquement) :
--   is_premium, premium_until                      -> RevenueCat / webhook
--   referral_code                                  -> trigger trg_set_referral_code
--   email_hash, phone_hash                         -> trigger de hachage HMAC
--   avatar_moderation_status / _moderated_at / _rejected_reason
--   display_name_moderation_status / _moderated_at / _rejected_reason
--                                                  -> Edge Functions de modération
--   notion_access_token, notion_connected_at, notion_database_id,
--   notion_workspace_id, notion_workspace_name     -> notion-oauth-callback
--   reengagement_last_bucket, reengagement_last_sent_at -> cron send-reengagement
--   raw_user_meta_data, last_sign_in_at, email_confirmed_at -> auth

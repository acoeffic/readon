-- Audit 14/08/2026 : la policy `Anon can view public profiles` autorise le rôle
-- `anon` à lire `profiles` sans restriction de colonne. Comme `profiles.email`
-- est renseigné pour 100 % des comptes, un simple
--   GET /rest/v1/profiles?select=display_name,email
-- avec la clé anon (extraite du binaire) renvoyait l'annuaire e-mail complet.

revoke select on public.profiles from anon;

grant select (
  id,
  display_name,
  avatar_url,
  is_premium,
  is_profile_private,
  hide_reading_hours,
  reading_habit,
  onboarding_completed,
  timezone,
  referral_code,
  avatar_moderation_status,
  display_name_moderation_status,
  created_at,
  updated_at
) on public.profiles to anon;

-- NOTE : `authenticated` conserve pour l'instant le SELECT complet, donc un
-- compte créé pour l'occasion peut toujours lire les e-mails. Le verrouiller
-- exige d'abord une release client : `settings_page.dart` fait un
-- `.update({'avatar_url': …}).select()` (select=*) qui casserait avec un
-- SELECT restreint par colonne. À faire après la prochaine release.

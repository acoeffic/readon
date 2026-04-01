-- Migration : Ajouter SET search_path = public à toutes les fonctions SECURITY DEFINER
-- qui ne l'ont pas. Empêche l'escalade de privilèges via injection de schema.
-- Idempotent : ALTER FUNCTION sur une fonction déjà corrigée est un no-op.

-- ── community_feed.sql ──
ALTER FUNCTION get_accepted_friend_count(UUID) SET search_path = public;
ALTER FUNCTION get_trending_books_by_sessions(INTEGER) SET search_path = public;
ALTER FUNCTION get_community_sessions(INTEGER) SET search_path = public;

-- ── flow_percentile.sql ──
ALTER FUNCTION get_flow_percentile() SET search_path = public;

-- ── delete_user_account (audit_log.sql) ──
ALTER FUNCTION delete_user_account() SET search_path = public;

-- ── streak_freezes.sql ──
ALTER FUNCTION get_freeze_status() SET search_path = public;
ALTER FUNCTION use_streak_freeze(DATE, BOOLEAN) SET search_path = public;
ALTER FUNCTION get_frozen_dates(UUID) SET search_path = public;

-- ── friend_profile_stats.sql ──
ALTER FUNCTION get_friend_profile_stats(UUID) SET search_path = public;

-- ── fix_group_members_rls_recursion.sql ──
ALTER FUNCTION is_group_member(UUID, UUID) SET search_path = public;
ALTER FUNCTION is_group_admin(UUID, UUID) SET search_path = public;
ALTER FUNCTION add_creator_as_admin() SET search_path = public;

-- ── complete_badges_system.sql ──
ALTER FUNCTION get_all_user_badges(UUID) SET search_path = public;
ALTER FUNCTION check_and_award_badges(UUID) SET search_path = public;

-- ── fix_user_search_function_v2.sql ──
ALTER FUNCTION get_user_search_data(UUID) SET search_path = public;

-- ── create_suggestions_functions.sql ──
ALTER FUNCTION get_friends_popular_books(UUID, INTEGER) SET search_path = public;
ALTER FUNCTION get_trending_books(INTEGER) SET search_path = public;

-- ── create_reading_groups.sql ──
ALTER FUNCTION get_user_groups(UUID) SET search_path = public;
ALTER FUNCTION get_public_groups(INT, INT) SET search_path = public;
ALTER FUNCTION get_group_invitations(UUID) SET search_path = public;
ALTER FUNCTION respond_to_group_invitation(UUID, BOOLEAN) SET search_path = public;

-- ── add_reading_goals.sql ──
ALTER FUNCTION get_reading_goals_progress(INT) SET search_path = public;

-- ── fix_feed_functions.sql / update_rpc_hidden_books.sql ──
ALTER FUNCTION get_friend_recent_sessions(UUID) SET search_path = public;

-- ── add_premium_and_reactions.sql ──
ALTER FUNCTION get_activity_reactions(INT) SET search_path = public;

-- ── add_friend_request_notification.sql ──
ALTER FUNCTION notify_friend_request() SET search_path = public;
ALTER FUNCTION get_user_notifications(UUID, INT, INT) SET search_path = public;

-- Note : get_all_user_badges(UUID) est déjà couvert ligne 31 (complete_badges_system)

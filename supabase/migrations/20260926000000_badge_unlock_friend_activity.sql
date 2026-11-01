-- ============================================================================
-- MIGRATION: Activité de feed d'amis pour les déblocages de badge
-- ============================================================================
-- Jusqu'ici, débloquer un badge n'émettait qu'un événement analytics
-- ('badge_unlocked' dans analytics_service.dart) — aucune trace dans
-- `activities`, donc aucun ami ne le voyait jamais dans son fil (seul
-- 'book_finished' y crée une ligne côté client ; 'reading_session' y est
-- créé par un trigger serveur depuis 20260530).
--
-- La seule vitrine sociale existante pour les badges est
-- `get_feed_bundle.badge_unlocks` (CommunityBadgeUnlockCard côté client) :
-- elle tire des inconnus au hasard (n'importe quel profil public,
-- `ub.user_id != v_uid`, aucun filtre d'amitié) et n'est chargée QUE pour les
-- utilisateurs ayant moins de 3 amis (FeedTier.mixed/trending — cf.
-- trending_service.dart / feed_page.dart). Les utilisateurs les plus
-- connectés (3+ amis, tier friendsOnly) ne voyaient donc jamais aucun signal
-- social sur les badges — ni les leurs, ni ceux de leurs amis.
--
-- On étend le trigger d'audit déjà existant sur user_badges
-- (`log_badge_awarded`, AFTER INSERT) pour qu'il crée aussi une vraie
-- activité de feed d'amis, en réutilisant exactement la même plomberie que
-- create_activity_on_session_end (20260530) : INSERT INTO activities, puis
-- le trigger fan_out_activity (déjà type-agnostique) la distribue dans
-- feed_items pour chaque ami accepté. block_hidden_content_activities (le
-- 2e trigger BEFORE INSERT sur activities) ne filtre que sur book_id/
-- session_id dans le payload — absents ici, donc sans effet.
--
-- Aucun changement Flutter côté attribution n'est requis : check_and_award_
-- badges / check_and_award_secret_badges / les badges de flow insèrent tous
-- dans user_badges avec ON CONFLICT (user_id, badge_id) DO NOTHING, donc
-- 1) tous passent par ce trigger, et 2) une ré-attribution qui ne fait rien
-- ne re-déclenche pas le trigger (pas de doublon possible dans le feed).
--
-- Exclusion volontaire : les badges secrets (is_secret = TRUE) ne créent pas
-- d'activité, pour rester cohérent avec le filtre déjà appliqué dans
-- get_feed_bundle.badge_unlocks — un badge secret reste une surprise
-- personnelle, pas un post.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.log_badge_awarded()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_badge RECORD;
BEGIN
  PERFORM write_audit_log(
    'award_badge',
    jsonb_build_object('badge_id', NEW.badge_id),
    NEW.user_id
  );

  -- Activité de feed d'amis — best-effort : ne doit jamais faire échouer
  -- l'attribution du badge elle-même si quelque chose tourne mal ici.
  BEGIN
    SELECT name, icon, color, category, COALESCE(is_secret, FALSE) AS is_secret
    INTO v_badge
    FROM badges
    WHERE id = NEW.badge_id;

    IF FOUND AND NOT v_badge.is_secret THEN
      INSERT INTO activities (author_id, type, payload, created_at)
      VALUES (
        NEW.user_id,
        'badge_unlocked',
        jsonb_build_object(
          'badge_id', NEW.badge_id,
          'badge_name', v_badge.name,
          'badge_icon', v_badge.icon,
          'badge_color', v_badge.color,
          'badge_category', v_badge.category
        ),
        COALESCE(NEW.unlocked_at, NOW())
      );
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'log_badge_awarded: activity insert suppressed % %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

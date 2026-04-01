-- Migration : Notifications internes pour réactions et commentaires
-- Crée des triggers qui insèrent automatiquement une notification
-- quand un utilisateur réagit ou commente l'activité d'un autre.

-- ═══════════════════════════════════════════════════════════════
-- 1. TRIGGER : Notification sur réaction (activity_reactions)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_activity_reaction()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_author UUID;
BEGIN
  -- Trouver l'auteur de l'activité
  SELECT author_id INTO v_activity_author
  FROM activities
  WHERE id = NEW.activity_id;

  -- Ne pas notifier si l'utilisateur réagit à sa propre activité
  IF v_activity_author IS NOT NULL AND v_activity_author != NEW.user_id THEN
    INSERT INTO notifications (user_id, from_user_id, type, activity_id, is_read, created_at)
    VALUES (v_activity_author, NEW.user_id, 'like', NEW.activity_id, false, NOW());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_reaction_notification ON activity_reactions;
CREATE TRIGGER trigger_reaction_notification
  AFTER INSERT ON activity_reactions
  FOR EACH ROW
  EXECUTE FUNCTION notify_activity_reaction();


-- ═══════════════════════════════════════════════════════════════
-- 2. TRIGGER : Notification sur commentaire (comments)
--    Note : on notifie à l'insertion (status='pending'),
--    car la modération peut prendre du temps et on veut
--    informer l'auteur de l'activité qu'il a reçu un commentaire.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_activity_comment()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_author UUID;
BEGIN
  -- Trouver l'auteur de l'activité
  SELECT author_id INTO v_activity_author
  FROM activities
  WHERE id = NEW.activity_id;

  -- Ne pas notifier si l'utilisateur commente sa propre activité
  IF v_activity_author IS NOT NULL AND v_activity_author != NEW.author_id THEN
    INSERT INTO notifications (user_id, from_user_id, type, activity_id, is_read, created_at)
    VALUES (v_activity_author, NEW.author_id, 'comment', NEW.activity_id, false, NOW());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_comment_notification ON comments;
CREATE TRIGGER trigger_comment_notification
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_activity_comment();

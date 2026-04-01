-- Migration : Fix friend request notifications
-- Problèmes corrigés :
-- 1. Pas de RLS policies sur notifications → watchUnreadCount() stream vide
-- 2. Fonction count_unread_notifications manquante
-- 3. Backfill des demandes d'amis pending sans notification
-- 4. Assurer que activity_id est nullable
-- 5. Re-créer le trigger (idempotent)

-- ═══════════════════════════════════════════════════════════════
-- 1. Assurer que activity_id est nullable (friend_request n'a pas d'activity)
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE notifications ALTER COLUMN activity_id DROP NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- 2. RLS policies sur notifications (corrige stream + markAllAsRead)
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════
-- 3. Re-créer le trigger notify_friend_request (idempotent)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION notify_friend_request()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    INSERT INTO notifications (user_id, from_user_id, type, is_read, created_at)
    VALUES (NEW.addressee_id, NEW.requester_id, 'friend_request', false, now());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_friend_request_notification ON friends;
CREATE TRIGGER trigger_friend_request_notification
  AFTER INSERT ON friends
  FOR EACH ROW
  EXECUTE FUNCTION notify_friend_request();

-- ═══════════════════════════════════════════════════════════════
-- 4. Backfill : Créer les notifications pour les demandes pending existantes
-- ═══════════════════════════════════════════════════════════════
INSERT INTO notifications (user_id, from_user_id, type, is_read, created_at)
SELECT f.addressee_id, f.requester_id, 'friend_request', false, f.created_at
FROM friends f
WHERE f.status = 'pending'
AND NOT EXISTS (
  SELECT 1 FROM notifications n
  WHERE n.user_id = f.addressee_id
  AND n.from_user_id = f.requester_id
  AND n.type = 'friend_request'
);

-- ═══════════════════════════════════════════════════════════════
-- 5. Créer count_unread_notifications (utilisé par le service Dart)
-- ═══════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS count_unread_notifications(UUID);
CREATE OR REPLACE FUNCTION count_unread_notifications(p_user_id UUID)
RETURNS BIGINT AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM notifications
    WHERE user_id = p_user_id AND is_read = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ═══════════════════════════════════════════════════════════════
-- 6. Re-créer get_user_notifications avec search_path fixé
-- ═══════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS get_user_notifications(UUID, INT, INT);
CREATE FUNCTION get_user_notifications(p_user_id UUID, p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)
RETURNS TABLE (
  id UUID,
  type TEXT,
  activity_id BIGINT,
  from_user_id UUID,
  from_user_name TEXT,
  from_user_avatar TEXT,
  activity_payload JSONB,
  comment_content TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    n.id,
    n.type,
    n.activity_id,
    n.from_user_id,
    COALESCE(p.display_name, 'Un utilisateur')::TEXT AS from_user_name,
    p.avatar_url::TEXT AS from_user_avatar,
    CASE
      WHEN n.type IN ('like', 'comment') AND a.id IS NOT NULL THEN
        jsonb_build_object('book_title', a.payload->>'book_title')
      WHEN n.type = 'group_join_request' THEN
        (
          SELECT jsonb_build_object(
            'group_id', gjr.group_id,
            'group_name', rg.name,
            'request_id', gjr.id,
            'request_status', gjr.status
          )
          FROM group_join_requests gjr
          JOIN reading_groups rg ON rg.id = gjr.group_id
          WHERE gjr.user_id = n.from_user_id
          AND EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = gjr.group_id AND gm.user_id = n.user_id AND gm.role = 'admin'
          )
          AND gjr.status = 'pending'
          ORDER BY gjr.created_at DESC
          LIMIT 1
        )
      ELSE NULL
    END AS activity_payload,
    CASE
      WHEN n.type = 'comment' THEN c.content
      ELSE NULL
    END AS comment_content,
    n.is_read,
    n.created_at
  FROM notifications n
  LEFT JOIN profiles p ON p.id = n.from_user_id
  LEFT JOIN activities a ON a.id = n.activity_id AND n.type IN ('like', 'comment')
  LEFT JOIN comments c ON c.activity_id = n.activity_id AND c.author_id = n.from_user_id AND n.type = 'comment'
  WHERE n.user_id = p_user_id
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

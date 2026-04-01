-- Migration : Notification interne quand un utilisateur demande à rejoindre un club
-- Insère une notification pour chaque administrateur du groupe concerné.

-- ═══════════════════════════════════════════════════════════════
-- 1. TRIGGER : Notification sur demande de join (group_join_requests)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_group_join_request()
RETURNS TRIGGER AS $$
DECLARE
  v_admin RECORD;
BEGIN
  -- Uniquement quand une nouvelle demande est créée (status = 'pending')
  IF NEW.status = 'pending' THEN
    -- Notifier chaque administrateur du groupe
    FOR v_admin IN
      SELECT user_id FROM group_members
      WHERE group_id = NEW.group_id AND role = 'admin'
    LOOP
      -- Ne pas notifier si l'admin est le demandeur (cas improbable)
      IF v_admin.user_id != NEW.user_id THEN
        INSERT INTO notifications (user_id, from_user_id, type, is_read, created_at)
        VALUES (v_admin.user_id, NEW.user_id, 'group_join_request', false, now());
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_group_join_request_notification ON group_join_requests;
CREATE TRIGGER trigger_group_join_request_notification
  AFTER INSERT ON group_join_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_group_join_request();

-- ═══════════════════════════════════════════════════════════════
-- 2. UPDATE get_user_notifications pour supporter group_join_request
--    On inclut le nom du groupe dans activity_payload
-- ═══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS get_user_notifications(UUID, INT, INT);
CREATE FUNCTION get_user_notifications(p_user_id UUID, p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)
RETURNS TABLE (
  id UUID,
  type TEXT,
  activity_id INT,
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
        jsonb_build_object('book_title', ub.title)
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
  LEFT JOIN user_books ub ON ub.id = a.user_book_id
  LEFT JOIN comments c ON c.activity_id = n.activity_id AND c.author_id = n.from_user_id AND n.type = 'comment'
  WHERE n.user_id = p_user_id
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

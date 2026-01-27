-- Rendre activity_id nullable pour supporter les notifications sans activité (ex: friend_request)
ALTER TABLE notifications ALTER COLUMN activity_id DROP NOT NULL;

-- Trigger pour créer une notification quand une demande d'ami est envoyée

CREATE OR REPLACE FUNCTION notify_friend_request()
RETURNS TRIGGER AS $$
BEGIN
  -- Uniquement quand une nouvelle demande est créée (status = 'pending')
  IF NEW.status = 'pending' THEN
    INSERT INTO notifications (user_id, from_user_id, type, is_read, created_at)
    VALUES (NEW.addressee_id, NEW.requester_id, 'friend_request', false, now());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer le trigger sur INSERT dans la table friends
DROP TRIGGER IF EXISTS trigger_friend_request_notification ON friends;
CREATE TRIGGER trigger_friend_request_notification
  AFTER INSERT ON friends
  FOR EACH ROW
  EXECUTE FUNCTION notify_friend_request();

-- Mettre à jour get_user_notifications pour supporter friend_request (LEFT JOIN sur activities)
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

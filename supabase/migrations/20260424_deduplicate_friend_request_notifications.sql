-- Cleanup: remove duplicate friend_request notifications
-- Keep only the most recent notification per (user_id, from_user_id, type='friend_request')

DELETE FROM notifications n
WHERE n.type = 'friend_request'
AND n.id NOT IN (
  SELECT DISTINCT ON (user_id, from_user_id) id
  FROM notifications
  WHERE type = 'friend_request'
  ORDER BY user_id, from_user_id, created_at DESC
);

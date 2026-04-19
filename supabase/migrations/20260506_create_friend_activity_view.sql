-- =====================================================
-- Migration: Create friend_activity_view
-- Vue qui joint les activités avec les profils auteurs,
-- filtrée pour ne montrer que les activités des amis
-- de l'utilisateur connecté.
-- =====================================================

DROP VIEW IF EXISTS friend_activity_view;

CREATE VIEW friend_activity_view AS
SELECT
  a.id,
  a.type,
  a.payload,
  a.author_id,
  a.created_at,
  p.display_name AS author_name,
  p.email AS author_email,
  p.avatar_url AS author_avatar
FROM activities a
JOIN profiles p ON p.id = a.author_id
WHERE EXISTS (
  SELECT 1 FROM friends f
  WHERE f.status = 'accepted'
  AND (
    (f.requester_id = auth.uid() AND f.addressee_id = a.author_id)
    OR (f.addressee_id = auth.uid() AND f.requester_id = a.author_id)
  )
);

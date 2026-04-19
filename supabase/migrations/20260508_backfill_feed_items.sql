-- =====================================================
-- Migration: Backfill feed_items depuis les activités existantes
--
-- Peuple la table feed_items avec les activités des 7 derniers
-- jours pour toutes les amitiés acceptées existantes.
-- À exécuter UNE SEULE FOIS après la migration fan-out.
-- =====================================================

-- Backfill : pour chaque activité des 7 derniers jours,
-- insérer dans le feed de chaque ami accepté de l'auteur
INSERT INTO feed_items (owner_id, activity_id, author_id, author_name, author_avatar, type, payload, created_at)
SELECT
  CASE
    WHEN f.requester_id = a.author_id THEN f.addressee_id
    ELSE f.requester_id
  END AS owner_id,
  a.id         AS activity_id,
  a.author_id,
  p.display_name AS author_name,
  p.avatar_url   AS author_avatar,
  a.type,
  a.payload,
  a.created_at
FROM activities a
JOIN profiles p ON p.id = a.author_id
JOIN friends f ON (f.requester_id = a.author_id OR f.addressee_id = a.author_id)
  AND f.status = 'accepted'
WHERE a.created_at >= NOW() - INTERVAL '7 days'
ON CONFLICT (owner_id, activity_id) DO NOTHING;

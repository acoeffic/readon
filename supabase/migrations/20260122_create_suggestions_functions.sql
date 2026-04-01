-- Migration pour les fonctions de suggestions de lecture
-- Date: 2026-01-20

-- Fonction pour récupérer les livres populaires parmi les amis
CREATE OR REPLACE FUNCTION get_friends_popular_books(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  book JSONB,
  friend_count INTEGER,
  friend_names TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  WITH user_friends AS (
    -- Récupérer les IDs des amis
    SELECT
      CASE
        WHEN user_id_1 = p_user_id THEN user_id_2
        ELSE user_id_1
      END AS friend_id
    FROM friendships
    WHERE (user_id_1 = p_user_id OR user_id_2 = p_user_id)
      AND status = 'accepted'
  ),
  friends_books AS (
    -- Récupérer les livres des amis (status reading ou finished récemment)
    SELECT
      ub.book_id,
      uf.friend_id,
      p.display_name
    FROM user_books ub
    INNER JOIN user_friends uf ON ub.user_id = uf.friend_id
    INNER JOIN profiles p ON uf.friend_id = p.id
    WHERE ub.status IN ('reading', 'finished')
      AND ub.updated_at > NOW() - INTERVAL '90 days' -- Activité récente (3 mois)
      -- Exclure les livres déjà dans la bibliothèque de l'utilisateur
      AND NOT EXISTS (
        SELECT 1 FROM user_books
        WHERE user_id = p_user_id AND book_id = ub.book_id
      )
  )
  SELECT
    to_jsonb(b.*) AS book,
    COUNT(DISTINCT fb.friend_id)::INTEGER AS friend_count,
    array_agg(DISTINCT fb.display_name) AS friend_names
  FROM friends_books fb
  INNER JOIN books b ON fb.book_id = b.id
  GROUP BY b.id
  ORDER BY friend_count DESC, b.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour récupérer les livres tendances (les plus ajoutés récemment)
CREATE OR REPLACE FUNCTION get_trending_books(
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  book JSONB,
  user_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    to_jsonb(b.*) AS book,
    COUNT(DISTINCT ub.user_id)::INTEGER AS user_count
  FROM user_books ub
  INNER JOIN books b ON ub.book_id = b.id
  WHERE ub.created_at > NOW() - INTERVAL '30 days' -- Livres ajoutés dans le dernier mois
  GROUP BY b.id
  HAVING COUNT(DISTINCT ub.user_id) >= 2 -- Au moins 2 utilisateurs
  ORDER BY user_count DESC, b.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_user_books_status_updated
  ON user_books(status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_books_created
  ON user_books(created_at DESC);

-- Commentaires
COMMENT ON FUNCTION get_friends_popular_books IS
  'Retourne les livres populaires parmi les amis de l''utilisateur';

COMMENT ON FUNCTION get_trending_books IS
  'Retourne les livres les plus tendances (les plus ajoutés récemment)';

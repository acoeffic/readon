-- Migration: Fix feed-related functions
-- Corrects table names, column names, and type mismatches

-- 1. Fix get_friends_popular_books to use 'friends' table instead of 'friendships'
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
    -- Récupérer les IDs des amis (table 'friends' avec requester_id/addressee_id)
    SELECT
      CASE
        WHEN requester_id = p_user_id THEN addressee_id
        ELSE requester_id
      END AS friend_id
    FROM friends
    WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
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
      AND ub.updated_at > NOW() - INTERVAL '90 days'
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

-- 2. Fix get_community_sessions to cast UUID to TEXT
CREATE OR REPLACE FUNCTION get_community_sessions(
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  session_id TEXT,
  start_page INTEGER,
  end_page INTEGER,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  session_created_at TIMESTAMPTZ,
  display_name TEXT,
  avatar_url TEXT,
  user_id UUID,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    rs.id::text AS session_id,  -- Cast UUID to TEXT
    rs.start_page,
    rs.end_page,
    rs.start_time,
    rs.end_time,
    rs.created_at AS session_created_at,
    p.display_name,
    p.avatar_url,
    p.id AS user_id,
    b.title AS book_title,
    b.author AS book_author,
    b.cover_url AS book_cover
  FROM reading_sessions rs
  JOIN profiles p ON p.id = rs.user_id
  JOIN books b ON b.id::text = rs.book_id
  WHERE COALESCE(p.is_profile_private, FALSE) = FALSE
    AND rs.end_time IS NOT NULL
    AND rs.created_at > NOW() - INTERVAL '24 hours'
    AND rs.user_id != auth.uid()
  ORDER BY rs.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Migration: Community feed content for users with few/no friends
-- Adds RPC functions for friend count, trending books, and community sessions

-- 1. Get accepted friend count for a user
CREATE OR REPLACE FUNCTION get_accepted_friend_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM friends
  WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
    AND status = 'accepted';
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_accepted_friend_count(UUID) TO authenticated;

-- 2. Get trending books by reading session count (last 7 days)
CREATE OR REPLACE FUNCTION get_trending_books_by_sessions(
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  book_id BIGINT,
  book_title TEXT,
  book_author TEXT,
  book_cover TEXT,
  session_count BIGINT,
  reader_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id AS book_id,
    b.title AS book_title,
    b.author AS book_author,
    b.cover_url AS book_cover,
    COUNT(DISTINCT rs.id) AS session_count,
    COUNT(DISTINCT rs.user_id) AS reader_count
  FROM books b
  JOIN reading_sessions rs ON rs.book_id = b.id::text
  WHERE rs.created_at > NOW() - INTERVAL '7 days'
    AND rs.end_time IS NOT NULL
  GROUP BY b.id, b.title, b.author, b.cover_url
  ORDER BY session_count DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_trending_books_by_sessions(INTEGER) TO authenticated;

-- 3. Get recent community sessions from public profiles
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
    rs.id AS session_id,
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

GRANT EXECUTE ON FUNCTION get_community_sessions(INTEGER) TO authenticated;

-- 4. Performance indexes
CREATE INDEX IF NOT EXISTS idx_reading_sessions_created_at_completed
  ON reading_sessions(created_at DESC)
  WHERE end_time IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_public
  ON profiles(id)
  WHERE COALESCE(is_profile_private, FALSE) = FALSE;

-- Migration: Switch get_feed from offset-based to cursor-based pagination
-- Uses created_at cursor instead of OFFSET for better performance at scale

CREATE OR REPLACE FUNCTION get_feed(
  p_user_id UUID,
  p_limit INT DEFAULT 20,
  p_cursor TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id BIGINT,
  type TEXT,
  payload JSONB,
  author_id UUID,
  author_name TEXT,
  author_email TEXT,
  author_avatar TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.type,
    a.payload,
    a.author_id,
    p.display_name AS author_name,
    p.email AS author_email,
    p.avatar_url AS author_avatar,
    a.created_at
  FROM activities a
  JOIN profiles p ON p.id = a.author_id
  WHERE a.author_id IN (
    SELECT
      CASE
        WHEN f.requester_id = p_user_id THEN f.addressee_id
        ELSE f.requester_id
      END
    FROM friends f
    WHERE (f.requester_id = p_user_id OR f.addressee_id = p_user_id)
      AND f.status = 'accepted'
  )
  AND (p_cursor IS NULL OR a.created_at < p_cursor)
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_feed(UUID, INT, TIMESTAMPTZ) TO authenticated;

-- Index to support cursor-based pagination on activities
CREATE INDEX IF NOT EXISTS idx_activities_created_at_desc
  ON activities(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activities_author_created
  ON activities(author_id, created_at DESC);

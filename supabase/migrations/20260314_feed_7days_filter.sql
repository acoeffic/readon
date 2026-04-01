-- Migration : Limiter le feed aux activités des 7 derniers jours
--
-- Les activités des amis sont désormais filtrées à une fenêtre de 7 jours,
-- pour éviter de remonter d'anciennes sessions qui n'ont plus de pertinence.

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
  AND a.created_at >= NOW() - INTERVAL '7 days'
  AND (p_cursor IS NULL OR a.created_at < p_cursor)
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_feed(UUID, INT, TIMESTAMPTZ) TO authenticated;

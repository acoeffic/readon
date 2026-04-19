-- Fix: Restore book_title fallback to books table AND enrich activity_payload
-- with session navigation data (session_id, book_id, start_page, end_page,
-- duration_minutes, book_author, book_cover_url) so the app can navigate
-- from a notification directly to the reading session detail page.

DROP FUNCTION IF EXISTS get_user_notifications(UUID, INT, INT);
CREATE FUNCTION get_user_notifications(p_user_id UUID, p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)
RETURNS TABLE (
  id UUID,
  type TEXT,
  activity_id BIGINT,
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
        jsonb_build_object(
          'book_title',      COALESCE(a.payload->>'book_title', b.title),
          'book_id',         COALESCE((a.payload->>'book_id')::TEXT, b.id::TEXT),
          'book_author',     COALESCE(a.payload->>'book_author', b.author),
          'book_cover_url',  COALESCE(a.payload->>'book_cover_url', b.cover_url),
          'session_id',      a.payload->>'session_id',
          'start_page',      (a.payload->>'start_page')::INT,
          'end_page',        (a.payload->>'end_page')::INT,
          'duration_minutes',(a.payload->>'duration_minutes')::INT,
          'author_id',       a.author_id
        )
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
  LEFT JOIN books b ON b.id = (a.payload->>'book_id')::BIGINT
    AND n.type IN ('like', 'comment')
    AND a.id IS NOT NULL
  LEFT JOIN comments c ON c.activity_id = n.activity_id AND c.author_id = n.from_user_id AND n.type = 'comment'
  WHERE n.user_id = p_user_id
  ORDER BY n.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

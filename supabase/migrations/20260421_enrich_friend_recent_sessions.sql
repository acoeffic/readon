-- Enrich get_friend_recent_sessions to return full session + book data
-- so friend profile can navigate to session detail page

CREATE OR REPLACE FUNCTION get_friend_recent_sessions(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_private BOOLEAN;
BEGIN
  -- Check if profile is private
  SELECT COALESCE(is_profile_private, FALSE)
  INTO v_is_private
  FROM profiles
  WHERE id = p_user_id;

  -- If profile is private, verify friendship
  IF v_is_private THEN
    IF NOT EXISTS (
      SELECT 1 FROM friends
      WHERE status = 'accepted'
      AND (
        (requester_id = auth.uid() AND addressee_id = p_user_id)
        OR (addressee_id = auth.uid() AND requester_id = p_user_id)
      )
    ) AND auth.uid() != p_user_id THEN
      RAISE EXCEPTION 'Not a friend';
    END IF;
  END IF;

  RETURN (
    SELECT json_agg(row_to_json(t))
    FROM (
      SELECT
        rs.id,
        rs.user_id,
        rs.start_page,
        rs.end_page,
        rs.start_time,
        rs.end_time,
        rs.book_id,
        rs.is_hidden,
        rs.reading_for,
        rs.created_at,
        rs.updated_at,
        b.id AS b_id,
        b.title AS book_title,
        b.author AS book_author,
        b.cover_url AS book_cover_url,
        b.page_count AS book_page_count
      FROM reading_sessions rs
      INNER JOIN user_books ub
        ON ub.book_id::text = rs.book_id AND ub.user_id = rs.user_id
      INNER JOIN books b ON b.id = ub.book_id
      WHERE rs.user_id = p_user_id
        AND rs.end_time IS NOT NULL
        AND ub.is_hidden = FALSE
      ORDER BY rs.end_time DESC
      LIMIT 5
    ) t
  );
END;
$$;

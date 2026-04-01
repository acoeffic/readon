-- Add friend_count to get_friend_profile_stats
-- So we can display the number of friends on someone's profile

CREATE OR REPLACE FUNCTION get_friend_profile_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
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

  SELECT json_build_object(
    'books_finished', (
      SELECT COUNT(*) FROM user_books
      WHERE user_id = p_user_id
        AND status = 'finished'
        AND is_hidden = FALSE
    ),
    'total_pages', COALESCE((
      SELECT SUM(rs.end_page - rs.start_page)
      FROM reading_sessions rs
      INNER JOIN user_books ub
        ON ub.book_id::text = rs.book_id AND ub.user_id = rs.user_id
      WHERE rs.user_id = p_user_id
        AND rs.end_page IS NOT NULL
        AND rs.start_page IS NOT NULL
        AND rs.end_time IS NOT NULL
        AND ub.is_hidden = FALSE
    ), 0),
    'total_minutes', COALESCE((
      SELECT SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 60)
      FROM reading_sessions rs
      INNER JOIN user_books ub
        ON ub.book_id::text = rs.book_id AND ub.user_id = rs.user_id
      WHERE rs.user_id = p_user_id
        AND rs.end_time IS NOT NULL
        AND ub.is_hidden = FALSE
    ), 0),
    'friend_count', (
      SELECT COUNT(*) FROM friends
      WHERE status = 'accepted'
      AND (requester_id = p_user_id OR addressee_id = p_user_id)
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

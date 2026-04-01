-- =====================================================
-- RPC: get_friend_profile_stats
-- Returns reading stats for a friend (books, pages, minutes)
-- Uses SECURITY DEFINER to bypass user_books RLS
-- =====================================================

CREATE OR REPLACE FUNCTION get_friend_profile_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  -- Verify the caller is a friend (accepted status)
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

  SELECT json_build_object(
    'books_finished', (
      SELECT COUNT(*) FROM user_books
      WHERE user_id = p_user_id AND status = 'finished'
    ),
    'total_pages', COALESCE((
      SELECT SUM(end_page - start_page)
      FROM reading_sessions
      WHERE user_id = p_user_id
        AND end_page IS NOT NULL
        AND start_page IS NOT NULL
        AND end_time IS NOT NULL
    ), 0),
    'total_minutes', COALESCE((
      SELECT SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 60)
      FROM reading_sessions
      WHERE user_id = p_user_id
        AND end_time IS NOT NULL
    ), 0)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

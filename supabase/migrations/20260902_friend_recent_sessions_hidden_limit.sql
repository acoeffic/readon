-- get_friend_recent_sessions : utilisée par la section « Sessions récentes »
-- du profil ami (friend_profile_page.dart, 02/09/2026).
--   • exclut désormais les sessions masquées (rs.is_hidden) — même règle que
--     get_friend_book_detail ; avant, une session masquée fuyait ici ;
--   • p_limit paramétrable (défaut 10) ;
--   • gate privé / blocage inchangée.

DROP FUNCTION IF EXISTS get_friend_recent_sessions(UUID);

CREATE OR REPLACE FUNCTION get_friend_recent_sessions(
  p_user_id UUID,
  p_limit INT DEFAULT 10
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_private BOOLEAN;
  v_is_blocked BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocker_id = auth.uid() AND blocked_id = p_user_id)
       OR (blocker_id = p_user_id AND blocked_id = auth.uid())
  ) INTO v_is_blocked;
  IF v_is_blocked THEN
    RETURN '[]'::json;
  END IF;

  SELECT COALESCE(is_profile_private, FALSE)
  INTO v_is_private
  FROM profiles
  WHERE id = p_user_id;

  IF v_is_private THEN
    IF NOT EXISTS (
      SELECT 1 FROM friends
      WHERE status = 'accepted'
      AND (
        (requester_id = auth.uid() AND addressee_id = p_user_id)
        OR (addressee_id = auth.uid() AND requester_id = p_user_id)
      )
    ) AND auth.uid() IS DISTINCT FROM p_user_id THEN
      RAISE EXCEPTION 'Not a friend';
    END IF;
  END IF;

  RETURN COALESCE((
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
        b.page_count AS book_page_count,
        b.isbn AS book_isbn,
        b.google_id AS book_google_id
      FROM reading_sessions rs
      INNER JOIN user_books ub
        ON ub.book_id::text = rs.book_id AND ub.user_id = rs.user_id
      INNER JOIN books b ON b.id = ub.book_id
      WHERE rs.user_id = p_user_id
        AND rs.end_time IS NOT NULL
        AND ub.is_hidden = FALSE
        AND COALESCE(rs.is_hidden, FALSE) = FALSE
      ORDER BY rs.end_time DESC
      LIMIT GREATEST(1, LEAST(p_limit, 50))
    ) t
  ), '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION get_friend_recent_sessions(UUID, INT) TO authenticated;

-- =====================================================
-- Migration: get_friend_books
-- Retourne les livres (en cours + terminés) d'un utilisateur
-- pour la page profil ami, en respectant :
--   - le blocage (user_blocks, dans les deux sens)
--   - la confidentialité du profil (is_profile_private + amitié)
--   - les livres cachés (user_books.is_hidden)
-- =====================================================

CREATE OR REPLACE FUNCTION get_friend_books(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_private BOOLEAN;
  v_is_blocked BOOLEAN;
BEGIN
  -- Gate blocage : aucun contenu si la relation est bloquée
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
    ) AND auth.uid() != p_user_id THEN
      RAISE EXCEPTION 'Not a friend';
    END IF;
  END IF;

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t))
    FROM (
      SELECT
        ub.status,
        ub.updated_at,
        b.id AS b_id,
        b.title AS book_title,
        b.author AS book_author,
        b.cover_url AS book_cover_url,
        b.isbn AS book_isbn,
        b.google_id AS book_google_id
      FROM user_books ub
      INNER JOIN books b ON b.id = ub.book_id
      WHERE ub.user_id = p_user_id
        AND ub.is_hidden = FALSE
        AND ub.status IN ('reading', 'finished')
      ORDER BY
        CASE ub.status WHEN 'reading' THEN 0 ELSE 1 END,
        ub.updated_at DESC
      LIMIT 60
    ) t
  ), '[]'::json);
END;
$$;

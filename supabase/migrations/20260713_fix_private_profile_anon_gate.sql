-- =====================================================
-- Migration: fix de la gate "profil privé" pour les appelants anonymes
--
-- Problème : les RPC du profil ami utilisaient
--   `AND auth.uid() != p_user_id`
-- Pour un appelant NON authentifié, auth.uid() est NULL et la
-- comparaison vaut NULL → le IF ne lève jamais l'exception →
-- les données d'un PROFIL PRIVÉ étaient accessibles en anonyme.
--
-- Correctif : `auth.uid() IS DISTINCT FROM p_user_id` (NULL-safe).
-- Comportement final :
--   - profil public  → visible par tout le monde (y compris anonyme)
--   - profil privé   → visible uniquement par les amis acceptés (et soi-même)
-- Fonctions corrigées : get_friend_books, get_friend_recent_sessions,
-- get_friend_profile_stats.
-- =====================================================

-- ─────────────────────────────────────────────────────
-- get_friend_books
-- ─────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────
-- get_friend_recent_sessions
-- ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_friend_recent_sessions(p_user_id UUID)
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

-- ─────────────────────────────────────────────────────
-- get_friend_profile_stats
-- (corps identique à la version déployée, seule la gate change)
-- ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_friend_profile_stats(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  v_is_private BOOLEAN;
BEGIN
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
$$;

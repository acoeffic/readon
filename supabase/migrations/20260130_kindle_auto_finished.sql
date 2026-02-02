-- =====================================================
-- Migration: kindle_auto_finished flag
-- =====================================================
-- Ajoute un flag pour distinguer les livres auto-finis lors du premier
-- sync Kindle (ne doivent pas compter dans les badges/trophees)

-- 1. Ajouter la colonne kindle_auto_finished a user_books
ALTER TABLE user_books
ADD COLUMN IF NOT EXISTS kindle_auto_finished BOOLEAN DEFAULT FALSE;

-- 2. Mettre a jour get_friend_profile_stats pour exclure les auto-finished
CREATE OR REPLACE FUNCTION get_friend_profile_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
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
      WHERE user_id = p_user_id
        AND status = 'finished'
        AND is_hidden = FALSE
        AND kindle_auto_finished = FALSE
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
    ), 0)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Mettre a jour get_user_search_data pour exclure les auto-finished du compteur
CREATE OR REPLACE FUNCTION get_user_search_data(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_is_private BOOLEAN;
  v_profile JSONB;
  v_badges JSONB;
  v_current_book JSONB;
  v_books_finished INT;
  v_friends_count INT;
  v_current_streak INT;
  v_current_user_id UUID;
  v_is_friend BOOLEAN;
BEGIN
  v_current_user_id := auth.uid();

  SELECT
    jsonb_build_object(
      'id', p.id,
      'display_name', p.display_name,
      'email', p.email,
      'avatar_url', p.avatar_url,
      'is_profile_private', COALESCE(p.is_profile_private, FALSE),
      'member_since', p.created_at
    )
  INTO v_profile
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  v_is_private := (v_profile->>'is_profile_private')::BOOLEAN;

  IF v_is_private THEN
    SELECT EXISTS (
      SELECT 1
      FROM friends
      WHERE ((requester_id = v_current_user_id AND addressee_id = p_user_id)
         OR (requester_id = p_user_id AND addressee_id = v_current_user_id))
        AND status = 'accepted'
    ) INTO v_is_friend;

    IF NOT v_is_friend OR v_current_user_id IS NULL THEN
      RETURN v_profile;
    END IF;
  END IF;

  -- Badges recents (3 plus recents)
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', ub.badge_id,
      'name', b.name,
      'icon', b.icon,
      'color', b.color,
      'unlocked_at', ub.unlocked_at
    )
    ORDER BY ub.unlocked_at DESC
  )
  INTO v_badges
  FROM user_badges ub
  JOIN badges b ON b.id = ub.badge_id
  WHERE ub.user_id = p_user_id
  LIMIT 3;

  -- Livre actuellement en cours (exclut les caches)
  SELECT jsonb_build_object(
    'id', ubk.id,
    'title', bk.title,
    'author', bk.author,
    'cover_url', bk.cover_url
  )
  INTO v_current_book
  FROM user_books ubk
  JOIN books bk ON bk.id = ubk.book_id
  WHERE ubk.user_id = p_user_id
    AND ubk.status = 'reading'
    AND ubk.is_hidden = FALSE
  ORDER BY ubk.updated_at DESC
  LIMIT 1;

  -- Nombre de livres termines (exclut les caches ET les auto-finished Kindle)
  SELECT COUNT(*)
  INTO v_books_finished
  FROM user_books
  WHERE user_id = p_user_id
    AND status = 'finished'
    AND is_hidden = FALSE
    AND kindle_auto_finished = FALSE;

  -- Nombre d'amis acceptes
  SELECT COUNT(*)
  INTO v_friends_count
  FROM friends
  WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
    AND status = 'accepted';

  -- Streak actuel
  v_current_streak := 0;
  BEGIN
    SELECT get_current_streak_for_user(p_user_id) INTO v_current_streak;
  EXCEPTION
    WHEN undefined_function THEN
      SELECT COUNT(DISTINCT DATE(start_time))
      INTO v_current_streak
      FROM reading_sessions
      WHERE user_id = p_user_id
        AND end_time IS NOT NULL
        AND start_time >= CURRENT_DATE - INTERVAL '7 days';
  END;

  v_result := v_profile || jsonb_build_object(
    'recent_badges', COALESCE(v_badges, '[]'::JSONB),
    'current_book', v_current_book,
    'books_finished', v_books_finished,
    'friends_count', v_friends_count,
    'current_streak', COALESCE(v_current_streak, 0)
  );

  RETURN v_result;
END;
$$;


-- =====================================================
-- 4. NOTE : Pas de modification necessaire pour les badges
-- =====================================================
-- count_completed_books compte les DISTINCT book_id depuis reading_sessions
-- (pas depuis user_books). Les livres auto-finis au premier sync Kindle
-- n'ont jamais de session de lecture, donc ne sont jamais comptes.
-- check_and_award_badges et get_all_user_badges en dependent, donc
-- sont naturellement proteges.
-- =====================================================

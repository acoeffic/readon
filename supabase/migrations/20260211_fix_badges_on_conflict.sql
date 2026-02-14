-- Migration : Protection anti-doublon sur user_badges
-- 1. Ajoute une contrainte UNIQUE (user_id, badge_id) pour éviter les doublons
-- 2. Remplace les INSERT dans check_and_award_badges par ON CONFLICT DO NOTHING

-- ============================================================================
-- 1. Supprimer les éventuels doublons existants avant d'ajouter la contrainte
-- ============================================================================
DELETE FROM user_badges a
USING user_badges b
WHERE a.ctid < b.ctid
  AND a.user_id = b.user_id
  AND a.badge_id = b.badge_id;

-- ============================================================================
-- 2. Ajouter la contrainte UNIQUE
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_badges_user_id_badge_id_key'
  ) THEN
    ALTER TABLE user_badges ADD CONSTRAINT user_badges_user_id_badge_id_key UNIQUE (user_id, badge_id);
  END IF;
END;
$$;

-- ============================================================================
-- 3. Recréer check_and_award_badges avec ON CONFLICT DO NOTHING + SET search_path
-- ============================================================================
DROP FUNCTION IF EXISTS check_and_award_badges(UUID);
CREATE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE (
  badge_id TEXT,
  badge_name TEXT,
  badge_icon TEXT,
  badge_color TEXT,
  badge_category TEXT,
  badge_is_premium BOOLEAN,
  badge_is_secret BOOLEAN,
  badge_is_animated BOOLEAN,
  badge_lottie_asset TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_completed_books INTEGER;
  v_total_reading_minutes INTEGER;
  v_session_count INTEGER;
  v_friend_count INTEGER;
  v_follower_count INTEGER;
  v_like_count INTEGER;
  v_comment_count INTEGER;
  v_goal_created_count INTEGER;
  v_goal_achieved_count INTEGER;
  v_distinct_genres INTEGER;
  v_fiction_count INTEGER;
  v_nonfiction_count INTEGER;
  v_has_profile BOOLEAN;
  v_account_age_days INTEGER;
  v_night_sessions INTEGER;
  v_morning_sessions INTEGER;
  rec RECORD;
BEGIN
  SELECT COUNT(*) INTO v_completed_books
  FROM user_books WHERE user_id = p_user_id AND status = 'finished';

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 60), 0)::INTEGER
  INTO v_total_reading_minutes
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL;

  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL;

  SELECT COUNT(*) INTO v_friend_count
  FROM friends WHERE (requester_id = p_user_id OR addressee_id = p_user_id) AND status = 'accepted';

  SELECT COUNT(*) INTO v_follower_count
  FROM friends WHERE addressee_id = p_user_id AND status = 'accepted';

  SELECT COUNT(*) INTO v_like_count FROM likes WHERE user_id = p_user_id;
  SELECT COUNT(*) INTO v_comment_count FROM comments WHERE user_id = p_user_id;

  SELECT COUNT(*) INTO v_goal_created_count FROM reading_goals WHERE user_id = p_user_id;
  SELECT COUNT(*) INTO v_goal_achieved_count FROM reading_goals WHERE user_id = p_user_id AND is_completed = true;

  SELECT COUNT(DISTINCT b.genre) INTO v_distinct_genres
  FROM user_books ub JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished' AND b.genre IS NOT NULL;

  SELECT COUNT(*) INTO v_fiction_count
  FROM user_books ub JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur');

  SELECT COUNT(*) INTO v_nonfiction_count
  FROM user_books ub JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre NOT IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur')
    AND b.genre IS NOT NULL;

  SELECT EXISTS(
    SELECT 1 FROM profiles WHERE id = p_user_id
      AND display_name IS NOT NULL AND display_name != '' AND avatar_url IS NOT NULL
  ) INTO v_has_profile;

  SELECT COALESCE(EXTRACT(DAY FROM (NOW() - created_at))::INTEGER, 0) INTO v_account_age_days
  FROM auth.users WHERE id = p_user_id;

  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) < 7;

  FOR rec IN
    SELECT b.*
    FROM badges b
    WHERE NOT EXISTS (
      SELECT 1 FROM user_badges ub WHERE ub.badge_id = b.id AND ub.user_id = p_user_id
    )
    AND b.category NOT IN ('streak', 'monthly', 'yearly')
  LOOP
    IF rec.category = 'books_completed' AND v_completed_books >= rec.requirement THEN
      INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
        ON CONFLICT (user_id, badge_id) DO NOTHING;
      RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
        COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
        COALESCE(rec.is_animated, false), rec.lottie_asset;

    ELSIF rec.category = 'reading_time' THEN
      IF (rec.id = 'time_first' AND v_session_count >= 1)
        OR (rec.id != 'time_first' AND v_total_reading_minutes >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'goals' THEN
      IF (rec.id = 'goal_created' AND v_goal_created_count >= 1)
        OR (rec.id = 'goal_achieved_1' AND v_goal_achieved_count >= 1)
        OR (rec.id = 'goal_achieved_5' AND v_goal_achieved_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'social' THEN
      IF (rec.id LIKE 'social_follow_%' AND v_friend_count >= rec.requirement)
        OR (rec.id = 'social_first_like' AND v_like_count >= 1)
        OR (rec.id = 'social_comments_10' AND v_comment_count >= 10)
        OR (rec.id LIKE 'social_followers_%' AND v_follower_count >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'genres' THEN
      IF (rec.id LIKE 'genre_explorer_%' AND v_distinct_genres >= rec.requirement)
        OR (rec.id = 'genre_fiction_5' AND v_fiction_count >= 5)
        OR (rec.id = 'genre_nonfiction_5' AND v_nonfiction_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'engagement' THEN
      IF (rec.id = 'engage_profile' AND v_has_profile) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'animated' THEN
      IF (rec.id = 'anim_night_owl' AND v_night_sessions >= 10)
        OR (rec.id = 'anim_early_bird' AND v_morning_sessions >= 10) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'secret' THEN
      IF (rec.id = 'secret_loyal_1y' AND v_account_age_days >= 365)
        OR (rec.id = 'secret_loyal_2y' AND v_account_age_days >= 730) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    END IF;
  END LOOP;
END;
$$;

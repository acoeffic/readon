-- 20260811_fix_streak_badges.sql
-- Bug : les badges de flow (category 'streak') n'ont JAMAIS été attribués en prod.
-- Cause : attribution côté client (flow_service.checkAndAwardFlowBadges) qui upsert
-- user_badges avec une colonne `earned_at` inexistante (la vraie colonne est
-- `unlocked_at`) → erreur PostgREST avalée par le try/catch, échec silencieux.
-- Les fonctions serveur excluaient explicitement la catégorie 'streak'
-- (« géré ailleurs » = le client cassé), et get_all_user_badges hardcodait la
-- progression streak à 0 (d'où le 0/3, 0/7 affiché).
--
-- Fix serveur :
-- 1. get_user_streak_stats(uuid) : calcul SQL du flow courant + record, en
--    répliquant les règles client (>=1 page, >=2 min, sessions manuelles
--    antidatées exclues, jours frozen inclus, timezone du profil).
-- 2. check_and_award_badges : attribue désormais les badges streak (sur le
--    record) — prend effet immédiatement pour les apps déjà déployées.
-- 3. get_all_user_badges : progression streak réelle au lieu de 0.
-- 4. Backfill rétroactif pour tous les utilisateurs.

-- =====================================================
-- 1. Calcul serveur du streak (interne, pas de GRANT app)
-- =====================================================
CREATE OR REPLACE FUNCTION public.get_user_streak_stats(p_user_id uuid)
RETURNS TABLE(current_streak integer, longest_streak integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tz text;
  v_today date;
BEGIN
  SELECT COALESCE(p.timezone, 'Europe/Paris') INTO v_tz
  FROM profiles p WHERE p.id = p_user_id;
  IF v_tz IS NULL OR v_tz = '' THEN
    v_tz := 'Europe/Paris';
  END IF;

  BEGIN
    v_today := (now() AT TIME ZONE v_tz)::date;
  EXCEPTION WHEN OTHERS THEN
    -- timezone invalide en base → fallback
    v_tz := 'Europe/Paris';
    v_today := (now() AT TIME ZONE v_tz)::date;
  END;

  RETURN QUERY
  WITH read_days AS (
    -- Mêmes règles que flow_service._sessionCountsForFlow :
    -- pages >= 1, durée >= 2 min, session manuelle antidatée exclue
    SELECT DISTINCT (rs.end_time AT TIME ZONE v_tz)::date AS d
    FROM reading_sessions rs
    WHERE rs.user_id = p_user_id
      AND rs.end_time IS NOT NULL
      AND rs.start_page IS NOT NULL
      AND rs.end_page IS NOT NULL
      AND (rs.end_page - rs.start_page) >= 1
      AND (rs.end_time - rs.start_time) >= interval '2 minutes'
      AND NOT (
        COALESCE(rs.is_manual, false)
        AND (rs.end_time AT TIME ZONE v_tz)::date
            <> (rs.created_at AT TIME ZONE v_tz)::date
      )
  ),
  valid_days AS (
    SELECT d FROM read_days
    UNION
    SELECT sf.frozen_date FROM streak_freezes sf WHERE sf.user_id = p_user_id
  ),
  runs AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d))::int AS grp
    FROM valid_days
  ),
  islands AS (
    SELECT MAX(d) AS end_d, COUNT(*)::int AS len
    FROM runs
    GROUP BY grp
  )
  SELECT
    -- flow courant : série se terminant aujourd'hui ou hier
    COALESCE((
      SELECT i.len FROM islands i
      WHERE i.end_d >= v_today - 1
      ORDER BY i.end_d DESC LIMIT 1
    ), 0),
    COALESCE((SELECT MAX(i.len) FROM islands i), 0);
END;
$$;

-- Fonction interne (appelée par les RPC SECURITY DEFINER) : aucun GRANT app.
REVOKE ALL ON FUNCTION public.get_user_streak_stats(uuid) FROM PUBLIC, anon, authenticated;

-- =====================================================
-- 2. check_and_award_badges : gère désormais 'streak'
-- =====================================================
CREATE OR REPLACE FUNCTION public.check_and_award_badges(p_user_id uuid)
 RETURNS TABLE(badge_id text, badge_name text, badge_icon text, badge_color text, badge_category text, badge_is_premium boolean, badge_is_secret boolean, badge_is_animated boolean, badge_lottie_asset text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
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
  v_days_since_last_session INTEGER;
  v_ratings_count INTEGER;
  v_reviews_count INTEGER;
  v_rated_genres_4 INTEGER;
  v_current_streak INTEGER;
  v_longest_streak INTEGER;
  rec RECORD;
BEGIN
  SELECT COUNT(*) INTO v_completed_books
  FROM user_books WHERE user_id = p_user_id AND status = 'finished';

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 60), 0)::INTEGER
  INTO v_total_reading_minutes
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE);

  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE);

  SELECT COUNT(*) INTO v_friend_count
  FROM friends WHERE (requester_id = p_user_id OR addressee_id = p_user_id) AND status = 'accepted';

  SELECT COUNT(*) INTO v_follower_count
  FROM friends WHERE addressee_id = p_user_id AND status = 'accepted';

  SELECT COUNT(*) INTO v_like_count FROM likes WHERE user_id = p_user_id;

  SELECT COUNT(*) INTO v_comment_count FROM comments WHERE author_id = p_user_id;

  SELECT COUNT(*) INTO v_goal_created_count FROM reading_goals WHERE user_id = p_user_id;

  v_goal_achieved_count := 0;

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
    AND (is_too_fast IS NOT TRUE)
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE)
    AND EXTRACT(HOUR FROM start_time) < 7;

  SELECT COALESCE(
    EXTRACT(DAY FROM (
      (SELECT start_time FROM reading_sessions
       WHERE user_id = p_user_id AND end_time IS NOT NULL AND (is_too_fast IS NOT TRUE)
       ORDER BY end_time DESC LIMIT 1)
      -
      (SELECT end_time FROM reading_sessions
       WHERE user_id = p_user_id AND end_time IS NOT NULL AND (is_too_fast IS NOT TRUE)
       ORDER BY end_time DESC LIMIT 1 OFFSET 1)
    ))::INTEGER,
    0
  ) INTO v_days_since_last_session;

  -- Compteurs de notation (badges 'ratings')
  SELECT COUNT(*) INTO v_ratings_count
  FROM book_ratings WHERE user_id = p_user_id;

  SELECT COUNT(*) INTO v_reviews_count
  FROM book_ratings WHERE user_id = p_user_id
    AND review_text IS NOT NULL AND length(trim(review_text)) > 0;

  SELECT COUNT(DISTINCT b.genre) INTO v_rated_genres_4
  FROM book_ratings br JOIN books b ON br.book_id = b.id
  WHERE br.user_id = p_user_id AND br.rating >= 4 AND b.genre IS NOT NULL;

  -- Streak (flow) : calcul serveur — fix 2026-08-11, les badges streak
  -- n'étaient attribués nulle part (le client upsertait une colonne inexistante)
  SELECT s.current_streak, s.longest_streak
  INTO v_current_streak, v_longest_streak
  FROM get_user_streak_stats(p_user_id) s;

  FOR rec IN
    SELECT b.*
    FROM badges b
    WHERE NOT EXISTS (
      SELECT 1 FROM user_badges ub WHERE ub.badge_id = b.id AND ub.user_id = p_user_id
    )
    AND b.category NOT IN ('monthly', 'yearly')
  LOOP
    IF rec.category = 'books_completed' AND v_completed_books >= rec.requirement THEN
      INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
        ON CONFLICT (user_id, badge_id) DO NOTHING;
      RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
        COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
        COALESCE(rec.is_animated, false), rec.lottie_asset;

    ELSIF rec.category = 'streak' THEN
      IF v_longest_streak >= rec.requirement THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'reading_time' THEN
      IF (rec.id = 'time_first' AND v_session_count >= 1)
        OR (rec.id != 'time_first' AND v_total_reading_minutes >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'goals' THEN
      IF (rec.id = 'goal_created' AND v_goal_created_count >= 1)
        OR (rec.id = 'goal_achieved_1' AND v_goal_achieved_count >= 1)
        OR (rec.id = 'goal_achieved_5' AND v_goal_achieved_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
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
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'genres' THEN
      IF (rec.id LIKE 'genre_explorer_%' AND v_distinct_genres >= rec.requirement)
        OR (rec.id = 'genre_fiction_5' AND v_fiction_count >= 5)
        OR (rec.id = 'genre_nonfiction_5' AND v_nonfiction_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'ratings' THEN
      IF (rec.id = 'first_rating' AND v_ratings_count >= 1)
        OR (rec.id = 'ratings_10' AND v_ratings_count >= 10)
        OR (rec.id = 'reviews_10' AND v_reviews_count >= 10)
        OR (rec.id = 'eclectic_5' AND v_rated_genres_4 >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'engagement' THEN
      IF (rec.id = 'engage_profile' AND v_has_profile) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'animated' THEN
      IF (rec.id = 'anim_night_owl' AND v_night_sessions >= 10)
        OR (rec.id = 'anim_early_bird' AND v_morning_sessions >= 10) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'secret' THEN
      IF (rec.id = 'secret_loyal_1y' AND v_account_age_days >= 365)
        OR (rec.id = 'secret_loyal_2y' AND v_account_age_days >= 730) THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'comeback' THEN
      IF v_days_since_last_session >= rec.requirement THEN
        INSERT INTO user_badges (user_id, badge_id, unlocked_at) VALUES (p_user_id, rec.id, NOW())
          ON CONFLICT (user_id, badge_id) DO NOTHING;
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    END IF;
  END LOOP;
END;
$function$;

-- =====================================================
-- 3. get_all_user_badges : progression streak réelle
-- =====================================================
CREATE OR REPLACE FUNCTION public.get_all_user_badges(p_user_id uuid)
 RETURNS TABLE(badge_id text, name text, description text, icon text, category text, requirement integer, color text, is_premium boolean, is_secret boolean, is_animated boolean, progress_unit text, lottie_asset text, sort_order integer, tier text, unlocked_at timestamp with time zone, progress integer, is_unlocked boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_account_age_days INTEGER;
  v_night_sessions INTEGER;
  v_morning_sessions INTEGER;
  v_has_profile BOOLEAN;
  v_has_kindle BOOLEAN;
  v_invite_count INTEGER;
  v_speed_violations INTEGER;
  v_days_since_last_session INTEGER;
  v_current_streak INTEGER;
  v_longest_streak INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_completed_books
  FROM user_books WHERE user_id = p_user_id AND status = 'finished';

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 60), 0)::INTEGER INTO v_total_reading_minutes
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL AND (is_too_fast IS NOT TRUE);

  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL AND (is_too_fast IS NOT TRUE);

  SELECT COUNT(*) INTO v_friend_count
  FROM friends WHERE (requester_id = p_user_id OR addressee_id = p_user_id) AND status = 'accepted';

  SELECT COUNT(*) INTO v_follower_count
  FROM friends WHERE addressee_id = p_user_id AND status = 'accepted';

  SELECT COUNT(*) INTO v_like_count FROM likes WHERE user_id = p_user_id;

  SELECT COUNT(*) INTO v_comment_count FROM comments WHERE author_id = p_user_id;

  SELECT COUNT(*) INTO v_goal_created_count FROM reading_goals WHERE user_id = p_user_id;

  v_goal_achieved_count := 0;

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

  SELECT COALESCE(EXTRACT(DAY FROM (NOW() - created_at))::INTEGER, 0) INTO v_account_age_days
  FROM auth.users WHERE id = p_user_id;

  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE) AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE) AND EXTRACT(HOUR FROM start_time) < 7;

  SELECT EXISTS(
    SELECT 1 FROM profiles WHERE id = p_user_id
      AND display_name IS NOT NULL AND display_name != '' AND avatar_url IS NOT NULL
  ) INTO v_has_profile;

  v_has_kindle := false;
  v_invite_count := 0;

  SELECT COUNT(*) INTO v_speed_violations FROM speed_violations WHERE user_id = p_user_id;

  SELECT COALESCE(
    EXTRACT(DAY FROM (
      (SELECT start_time FROM reading_sessions
       WHERE user_id = p_user_id AND end_time IS NOT NULL AND (is_too_fast IS NOT TRUE)
       ORDER BY end_time DESC LIMIT 1)
      -
      (SELECT end_time FROM reading_sessions
       WHERE user_id = p_user_id AND end_time IS NOT NULL AND (is_too_fast IS NOT TRUE)
       ORDER BY end_time DESC LIMIT 1 OFFSET 1)
    ))::INTEGER, 0
  ) INTO v_days_since_last_session;

  -- Streak (flow) : calcul serveur — fix 2026-08-11 (progression était hardcodée à 0)
  SELECT s.current_streak, s.longest_streak
  INTO v_current_streak, v_longest_streak
  FROM get_user_streak_stats(p_user_id) s;

  RETURN QUERY
  SELECT
    b.id AS badge_id, b.name, b.description, b.icon, b.category, b.requirement, b.color,
    COALESCE(b.is_premium, false) AS is_premium,
    COALESCE(b.is_secret, false) AS is_secret,
    COALESCE(b.is_animated, false) AS is_animated,
    COALESCE(b.progress_unit, '') AS progress_unit,
    NULL::TEXT AS lottie_asset,
    COALESCE(b.sort_order, 0) AS sort_order,
    b.tier,
    ub.unlocked_at AS unlocked_at,
    CASE b.category
      WHEN 'books_completed' THEN LEAST(v_completed_books, b.requirement)
      WHEN 'reading_time' THEN
        CASE b.id WHEN 'time_first' THEN LEAST(v_session_count, 1) ELSE LEAST(v_total_reading_minutes, b.requirement) END
      WHEN 'streak' THEN LEAST(v_longest_streak, b.requirement)
      WHEN 'goals' THEN
        CASE b.id WHEN 'goal_created' THEN LEAST(v_goal_created_count, 1) ELSE LEAST(v_goal_achieved_count, b.requirement) END
      WHEN 'social' THEN
        CASE
          WHEN b.id LIKE 'social_follow_%' THEN LEAST(v_friend_count, b.requirement)
          WHEN b.id = 'social_first_like' THEN LEAST(v_like_count, 1)
          WHEN b.id = 'social_comments_%' THEN LEAST(v_comment_count, b.requirement)
          WHEN b.id LIKE 'social_followers_%' THEN LEAST(v_follower_count, b.requirement)
          WHEN b.id LIKE 'social_invite_%' THEN LEAST(v_invite_count, b.requirement)
          WHEN b.id LIKE 'social_reviews_%' THEN LEAST(v_comment_count, b.requirement)
          ELSE 0
        END
      WHEN 'genres' THEN
        CASE
          WHEN b.id LIKE 'genre_explorer_%' THEN LEAST(v_distinct_genres, b.requirement)
          WHEN b.id = 'genre_fiction_5' THEN LEAST(v_fiction_count, b.requirement)
          WHEN b.id = 'genre_nonfiction_5' THEN LEAST(v_nonfiction_count, b.requirement)
          ELSE 0
        END
      WHEN 'engagement' THEN
        CASE b.id
          WHEN 'engage_profile' THEN CASE WHEN v_has_profile THEN 1 ELSE 0 END
          WHEN 'engage_kindle' THEN CASE WHEN v_has_kindle THEN 1 ELSE 0 END
          WHEN 'engage_invite_1' THEN LEAST(v_invite_count, 1)
          ELSE 0
        END
      WHEN 'animated' THEN
        CASE b.id
          WHEN 'anim_night_owl' THEN LEAST(v_night_sessions, b.requirement)
          WHEN 'anim_early_bird' THEN LEAST(v_morning_sessions, b.requirement)
          ELSE 0
        END
      WHEN 'secret' THEN
        CASE b.id
          WHEN 'secret_loyal_1y' THEN LEAST(v_account_age_days, 365)
          WHEN 'secret_loyal_2y' THEN LEAST(v_account_age_days, 730)
          WHEN 'secret_flash' THEN LEAST(v_speed_violations, 3)
          ELSE 0
        END
      WHEN 'comeback' THEN LEAST(v_days_since_last_session, b.requirement)
      ELSE 0
    END AS progress,
    (ub.unlocked_at IS NOT NULL) AS is_unlocked
  FROM badges b
  LEFT JOIN user_badges ub ON ub.badge_id = b.id AND ub.user_id = p_user_id
  ORDER BY b.category, COALESCE(b.sort_order, 0), b.requirement;
END;
$function$;

-- =====================================================
-- 4. Backfill rétroactif : attribuer les badges streak mérités
-- =====================================================
INSERT INTO user_badges (user_id, badge_id, unlocked_at)
SELECT p.id, b.id, NOW()
FROM profiles p
CROSS JOIN LATERAL get_user_streak_stats(p.id) s
JOIN badges b ON b.category = 'streak' AND b.requirement <= s.longest_streak
ON CONFLICT (user_id, badge_id) DO NOTHING;

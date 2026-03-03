-- Migration : Remettre ON CONFLICT DO NOTHING dans check_and_award_badges
-- La migration 20260216_speed_cap_anticheat avait recréé la fonction sans cette protection,
-- ce qui peut causer des erreurs de contrainte unique en cas d'appels concurrents.
--
-- + Ajout des 6 badges Comeback (Retour) et logique associée.
-- + Mise à jour de get_all_user_badges pour la progression comeback.

-- ============================================================================
-- 1. INSERTION DES 6 BADGES COMEBACK
-- ============================================================================

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('comeback_3d',  'Petit Retour',       'Revenir après 3 jours sans lire',      '👋', 'comeback', 3,  '#81C784', false, false, 'jours', 1),
  ('comeback_5d',  'De Retour',          'Revenir après 5 jours sans lire',      '🔄', 'comeback', 5,  '#66BB6A', false, false, 'jours', 2),
  ('comeback_1w',  'Semaine Retrouvée',  'Revenir après 1 semaine sans lire',    '📅', 'comeback', 7,  '#4CAF50', false, false, 'jours', 3),
  ('comeback_2w',  'Lecteur Fidèle',     'Revenir après 2 semaines sans lire',   '💪', 'comeback', 14, '#43A047', false, false, 'jours', 4),
  ('comeback_1m',  'Le Grand Retour',    'Revenir après 1 mois sans lire',       '🌟', 'comeback', 30, '#388E3C', false, false, 'jours', 5),
  ('comeback_3m',  'Le Phénix Lecteur',  'Revenir après 3 mois sans lire',       '🔥', 'comeback', 90, '#2E7D32', false, false, 'jours', 6)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  category = EXCLUDED.category,
  requirement = EXCLUDED.requirement,
  color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium,
  is_secret = EXCLUDED.is_secret,
  progress_unit = EXCLUDED.progress_unit,
  sort_order = EXCLUDED.sort_order;

-- ============================================================================
-- 2. check_and_award_badges (ON CONFLICT DO NOTHING + comeback)
-- ============================================================================

CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
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
  v_days_since_last_session INTEGER;
  rec RECORD;
BEGIN
  -- Calculer les statistiques

  SELECT COUNT(*) INTO v_completed_books
  FROM user_books WHERE user_id = p_user_id AND status = 'finished';

  -- Exclut sessions trop rapides
  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 60), 0)::INTEGER
  INTO v_total_reading_minutes
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE);

  -- Exclut sessions trop rapides
  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE);

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

  -- Exclut sessions trop rapides
  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE)
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  -- Exclut sessions trop rapides
  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE)
    AND EXTRACT(HOUR FROM start_time) < 7;

  -- Jours d'inactivité entre les 2 dernières sessions complétées
  -- (gap entre la fin de l'avant-dernière session et le début de la dernière)
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

  -- Parcourir tous les badges non encore attribués
  FOR rec IN
    SELECT b.*
    FROM badges b
    WHERE NOT EXISTS (
      SELECT 1 FROM user_badges ub WHERE ub.badge_id = b.id AND ub.user_id = p_user_id
    )
    -- Exclure les badges streak (gérés côté client), mensuels et annuels (gérés manuellement)
    AND b.category NOT IN ('streak', 'monthly', 'yearly')
  LOOP
    -- Vérifier la condition selon la catégorie
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

    ELSIF rec.category = 'comeback' THEN
      IF v_days_since_last_session >= rec.requirement THEN
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

-- ============================================================================
-- 3. get_all_user_badges (ajout progression comeback)
-- ============================================================================

DROP FUNCTION IF EXISTS get_all_user_badges(UUID);

CREATE OR REPLACE FUNCTION get_all_user_badges(p_user_id UUID)
RETURNS TABLE (
  badge_id TEXT,
  name TEXT,
  description TEXT,
  icon TEXT,
  category TEXT,
  requirement INTEGER,
  color TEXT,
  is_premium BOOLEAN,
  is_secret BOOLEAN,
  is_animated BOOLEAN,
  progress_unit TEXT,
  lottie_asset TEXT,
  sort_order INTEGER,
  tier TEXT,
  unlocked_at TIMESTAMPTZ,
  progress INTEGER,
  is_unlocked BOOLEAN
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
  v_account_age_days INTEGER;
  v_night_sessions INTEGER;
  v_morning_sessions INTEGER;
  v_has_profile BOOLEAN;
  v_has_kindle BOOLEAN;
  v_invite_count INTEGER;
  v_speed_violations INTEGER;
  v_days_since_last_session INTEGER;
BEGIN
  -- Calculer les statistiques de l'utilisateur

  -- Livres terminés
  SELECT COUNT(*) INTO v_completed_books
  FROM user_books
  WHERE user_id = p_user_id AND status = 'finished';

  -- Temps total de lecture (en minutes) — exclut sessions trop rapides
  SELECT COALESCE(SUM(
    EXTRACT(EPOCH FROM (end_time - start_time)) / 60
  ), 0)::INTEGER INTO v_total_reading_minutes
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE);

  -- Nombre de sessions — exclut sessions trop rapides
  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE);

  -- Amis (suivis acceptés)
  SELECT COUNT(*) INTO v_friend_count
  FROM friends
  WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
    AND status = 'accepted';

  -- Followers
  SELECT COUNT(*) INTO v_follower_count
  FROM friends
  WHERE addressee_id = p_user_id AND status = 'accepted';

  -- Likes donnés
  SELECT COUNT(*) INTO v_like_count
  FROM likes
  WHERE user_id = p_user_id;

  -- Commentaires écrits
  SELECT COUNT(*) INTO v_comment_count
  FROM comments
  WHERE author_id = p_user_id;

  -- Objectifs créés
  SELECT COUNT(*) INTO v_goal_created_count
  FROM reading_goals
  WHERE user_id = p_user_id;

  -- Objectifs atteints (pas de colonne is_completed, on met 0 pour l'instant)
  v_goal_achieved_count := 0;

  -- Genres distincts lus
  SELECT COUNT(DISTINCT b.genre) INTO v_distinct_genres
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished' AND b.genre IS NOT NULL;

  -- Livres fiction (genres fiction)
  SELECT COUNT(*) INTO v_fiction_count
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur');

  -- Livres non-fiction
  SELECT COUNT(*) INTO v_nonfiction_count
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = p_user_id AND ub.status = 'finished'
    AND b.genre NOT IN ('Fiction', 'Roman', 'Fantasy', 'Science-Fiction', 'Romance', 'Thriller', 'Policier', 'Horreur')
    AND b.genre IS NOT NULL;

  -- Ancienneté du compte (jours)
  SELECT COALESCE(
    EXTRACT(DAY FROM (NOW() - created_at))::INTEGER, 0
  ) INTO v_account_age_days
  FROM auth.users
  WHERE id = p_user_id;

  -- Sessions après minuit (00:00-05:00) — exclut sessions trop rapides
  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE)
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  -- Sessions avant 7h — exclut sessions trop rapides
  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND (is_too_fast IS NOT TRUE)
    AND EXTRACT(HOUR FROM start_time) < 7;

  -- Profil complété
  SELECT EXISTS(
    SELECT 1 FROM profiles
    WHERE id = p_user_id
      AND display_name IS NOT NULL
      AND display_name != ''
      AND avatar_url IS NOT NULL
  ) INTO v_has_profile;

  -- Kindle lié
  v_has_kindle := false;

  -- Invitations
  v_invite_count := 0;

  -- Violations de vitesse (pour progression secret_flash)
  SELECT COUNT(*) INTO v_speed_violations
  FROM speed_violations
  WHERE user_id = p_user_id;

  -- Jours d'inactivité entre les 2 dernières sessions complétées
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

  -- Retourner tous les badges avec leur progression
  RETURN QUERY
  SELECT
    b.id AS badge_id,
    b.name,
    b.description,
    b.icon,
    b.category,
    b.requirement,
    b.color,
    COALESCE(b.is_premium, false) AS is_premium,
    COALESCE(b.is_secret, false) AS is_secret,
    COALESCE(b.is_animated, false) AS is_animated,
    COALESCE(b.progress_unit, '') AS progress_unit,
    NULL::TEXT AS lottie_asset,
    COALESCE(b.sort_order, 0) AS sort_order,
    b.tier,
    ub.unlocked_at AS unlocked_at,
    -- Calculer la progression selon la catégorie
    CASE b.category
      WHEN 'books_completed' THEN LEAST(v_completed_books, b.requirement)
      WHEN 'reading_time' THEN
        CASE b.id
          WHEN 'time_first' THEN LEAST(v_session_count, 1)
          ELSE LEAST(v_total_reading_minutes, b.requirement)
        END
      WHEN 'streak' THEN 0
      WHEN 'goals' THEN
        CASE b.id
          WHEN 'goal_created' THEN LEAST(v_goal_created_count, 1)
          ELSE LEAST(v_goal_achieved_count, b.requirement)
        END
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
$$;

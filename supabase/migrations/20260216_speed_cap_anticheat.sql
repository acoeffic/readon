-- ============================================================================
-- MIGRATION: Plafond de vitesse souple + Badge "Flash Reader"
-- ============================================================================
-- Détecte les sessions > 3 pages/min, les exclut des stats de badges,
-- et débloque un badge secret humoristique après 3 infractions.
-- ============================================================================

-- ============================================================================
-- 1. COLONNE is_too_fast SUR reading_sessions
-- ============================================================================

ALTER TABLE reading_sessions
ADD COLUMN IF NOT EXISTS is_too_fast BOOLEAN DEFAULT FALSE;

-- Index partiel pour filtrage efficace dans les RPCs de badges
CREATE INDEX IF NOT EXISTS idx_reading_sessions_too_fast
  ON reading_sessions(user_id, is_too_fast)
  WHERE is_too_fast = TRUE;

-- ============================================================================
-- 2. TABLE speed_violations (backend-only, même pattern que audit_log)
-- ============================================================================

CREATE TABLE IF NOT EXISTS speed_violations (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id       UUID NOT NULL REFERENCES reading_sessions(id) ON DELETE CASCADE,
  pages_read       INTEGER NOT NULL,
  duration_minutes DOUBLE PRECISION NOT NULL,
  pages_per_minute DOUBLE PRECISION NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_speed_violations_user ON speed_violations(user_id);
CREATE INDEX IF NOT EXISTS idx_speed_violations_session ON speed_violations(session_id);

-- RLS activé sans policy = aucun accès direct pour les utilisateurs
ALTER TABLE speed_violations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. BADGE secret_flash
-- ============================================================================

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_secret, progress_unit, sort_order)
VALUES (
  'secret_flash',
  'Flash Reader',
  'Même Flash ne tourne pas les pages aussi vite...',
  '⚡',
  'secret',
  3,
  '#FFD700',
  true,
  'sessions',
  9
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  category = EXCLUDED.category,
  requirement = EXCLUDED.requirement,
  color = EXCLUDED.color,
  is_secret = EXCLUDED.is_secret,
  progress_unit = EXCLUDED.progress_unit,
  sort_order = EXCLUDED.sort_order;

-- ============================================================================
-- 4. RPC: check_and_award_secret_badges (avec détection de vitesse)
-- ============================================================================

CREATE OR REPLACE FUNCTION check_and_award_secret_badges(
  p_session_id UUID,
  p_book_finished BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  badge_id   TEXT,
  badge_name TEXT,
  badge_desc TEXT,
  badge_icon TEXT,
  badge_color TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID;
  v_start_time TIMESTAMPTZ;
  v_end_time   TIMESTAMPTZ;
  v_start_hour INT;
  v_start_min  INT;
  v_end_hour   INT;
  v_start_month INT;
  v_start_day   INT;
  -- Speed cap variables
  v_start_page   INTEGER;
  v_end_page     INTEGER;
  v_pages_read   INTEGER;
  v_duration_min DOUBLE PRECISION;
  v_pages_per_min DOUBLE PRECISION;
  v_violation_count INTEGER;
BEGIN
  -- Récupérer la session depuis la base (timestamps serveur, non manipulables)
  SELECT rs.user_id, rs.start_time, rs.end_time, rs.start_page, rs.end_page
  INTO v_user_id, v_start_time, v_end_time, v_start_page, v_end_page
  FROM reading_sessions rs
  WHERE rs.id = p_session_id;

  IF v_user_id IS NULL THEN
    RETURN; -- session inexistante
  END IF;

  -- Vérifier que c'est bien la session de l'utilisateur courant
  IF v_user_id != auth.uid() THEN
    RETURN;
  END IF;

  -- Extraire les composants temporels
  v_start_hour  := EXTRACT(HOUR FROM v_start_time);
  v_start_min   := EXTRACT(MINUTE FROM v_start_time);
  v_start_month := EXTRACT(MONTH FROM v_start_time);
  v_start_day   := EXTRACT(DAY FROM v_start_time);

  IF v_end_time IS NOT NULL THEN
    v_end_hour := EXTRACT(HOUR FROM v_end_time);
  END IF;

  -- ── Minuit Pile : session commencée à 00:00 ──
  IF v_start_hour = 0 AND v_start_min = 0
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_midnight'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_midnight', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_midnight';
  END IF;

  -- ── Premier de l'An : lire le 1er janvier ──
  IF v_start_month = 1 AND v_start_day = 1
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_new_year'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_new_year', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_new_year';
  END IF;

  -- ── Marathon Nocturne : lire de 22h à 6h ──
  IF v_end_time IS NOT NULL
     AND v_start_hour >= 22 AND v_end_hour < 6
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_night_marathon'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_night_marathon', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_night_marathon';
  END IF;

  -- ── Finisher : terminer un livre ──
  IF p_book_finished
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_finisher'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_finisher', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_finisher';
  END IF;

  -- ── Palindrome : jour == mois (01/01, 02/02, … 12/12) ──
  IF v_start_month = v_start_day
     AND NOT EXISTS (
       SELECT 1 FROM user_badges ub
       WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_palindrome'
     )
  THEN
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    VALUES (v_user_id, 'secret_palindrome', NOW())
    ON CONFLICT DO NOTHING;

    RETURN QUERY
      SELECT b.id, b.name, b.description, b.icon, b.color
      FROM badges b WHERE b.id = 'secret_palindrome';
  END IF;

  -- ── Speed Cap : détection sessions > 3 pages/minute ──
  IF v_end_time IS NOT NULL AND v_end_page IS NOT NULL AND v_start_page IS NOT NULL THEN
    v_pages_read := v_end_page - v_start_page;
    v_duration_min := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) / 60.0;

    -- Guard contre division par zéro et sessions invalides
    IF v_duration_min > 0 AND v_pages_read > 0 THEN
      v_pages_per_min := v_pages_read::DOUBLE PRECISION / v_duration_min;

      IF v_pages_per_min > 3.0 THEN
        -- 1. Flaguer la session
        UPDATE reading_sessions
        SET is_too_fast = TRUE
        WHERE id = p_session_id;

        -- 2. Enregistrer la violation (table backend-only)
        INSERT INTO speed_violations (user_id, session_id, pages_read, duration_minutes, pages_per_minute)
        VALUES (v_user_id, p_session_id, v_pages_read, v_duration_min, v_pages_per_min);

        -- 3. Logger dans l'audit trail
        PERFORM write_audit_log(
          'speed_violation',
          jsonb_build_object(
            'session_id', p_session_id,
            'pages_read', v_pages_read,
            'duration_minutes', round(v_duration_min::numeric, 2),
            'pages_per_minute', round(v_pages_per_min::numeric, 2)
          ),
          v_user_id
        );

        -- 4. Vérifier si 3 violations atteintes → débloquer secret_flash
        SELECT COUNT(*) INTO v_violation_count
        FROM speed_violations
        WHERE user_id = v_user_id;

        IF v_violation_count >= 3
           AND NOT EXISTS (
             SELECT 1 FROM user_badges ub
             WHERE ub.user_id = v_user_id AND ub.badge_id = 'secret_flash'
           )
        THEN
          INSERT INTO user_badges (user_id, badge_id, earned_at)
          VALUES (v_user_id, 'secret_flash', NOW())
          ON CONFLICT DO NOTHING;

          RETURN QUERY
            SELECT b.id, b.name, b.description, b.icon, b.color
            FROM badges b WHERE b.id = 'secret_flash';
        END IF;
      END IF;
    END IF;
  END IF;

END;
$$;

GRANT EXECUTE ON FUNCTION check_and_award_secret_badges(UUID, BOOLEAN) TO authenticated;

-- ============================================================================
-- 5. RPC: get_all_user_badges (avec filtrage is_too_fast + progression secret_flash)
-- ============================================================================
-- Basé sur la version de 20260211_add_badge_tiers.sql avec le champ tier

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
      ELSE 0
    END AS progress,
    (ub.unlocked_at IS NOT NULL) AS is_unlocked
  FROM badges b
  LEFT JOIN user_badges ub ON ub.badge_id = b.id AND ub.user_id = p_user_id
  ORDER BY b.category, COALESCE(b.sort_order, 0), b.requirement;
END;
$$;

-- ============================================================================
-- 6. RPC: check_and_award_badges (avec filtrage is_too_fast)
-- ============================================================================
-- Basé sur la version de 20260201_complete_badges_system.sql

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
      INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
      RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
        COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
        COALESCE(rec.is_animated, false), rec.lottie_asset;

    ELSIF rec.category = 'reading_time' THEN
      IF (rec.id = 'time_first' AND v_session_count >= 1)
        OR (rec.id != 'time_first' AND v_total_reading_minutes >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'goals' THEN
      IF (rec.id = 'goal_created' AND v_goal_created_count >= 1)
        OR (rec.id = 'goal_achieved_1' AND v_goal_achieved_count >= 1)
        OR (rec.id = 'goal_achieved_5' AND v_goal_achieved_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'social' THEN
      IF (rec.id LIKE 'social_follow_%' AND v_friend_count >= rec.requirement)
        OR (rec.id = 'social_first_like' AND v_like_count >= 1)
        OR (rec.id = 'social_comments_10' AND v_comment_count >= 10)
        OR (rec.id LIKE 'social_followers_%' AND v_follower_count >= rec.requirement) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'genres' THEN
      IF (rec.id LIKE 'genre_explorer_%' AND v_distinct_genres >= rec.requirement)
        OR (rec.id = 'genre_fiction_5' AND v_fiction_count >= 5)
        OR (rec.id = 'genre_nonfiction_5' AND v_nonfiction_count >= 5) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'engagement' THEN
      IF (rec.id = 'engage_profile' AND v_has_profile) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'animated' THEN
      IF (rec.id = 'anim_night_owl' AND v_night_sessions >= 10)
        OR (rec.id = 'anim_early_bird' AND v_morning_sessions >= 10) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    ELSIF rec.category = 'secret' THEN
      IF (rec.id = 'secret_loyal_1y' AND v_account_age_days >= 365)
        OR (rec.id = 'secret_loyal_2y' AND v_account_age_days >= 730) THEN
        INSERT INTO user_badges (user_id, badge_id, earned_at) VALUES (p_user_id, rec.id, NOW());
        RETURN QUERY SELECT rec.id, rec.name, rec.icon, rec.color, rec.category,
          COALESCE(rec.is_premium, false), COALESCE(rec.is_secret, false),
          COALESCE(rec.is_animated, false), rec.lottie_asset;
      END IF;

    END IF;
  END LOOP;
END;
$$;

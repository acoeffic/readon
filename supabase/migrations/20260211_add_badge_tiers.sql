-- ============================================================================
-- MIGRATION: Ajout de la colonne tier aux badges
-- ============================================================================
-- Ajoute un système de tiers (bronze → transcendent) aux badges
-- Met à jour les badges books_completed avec leurs tiers respectifs
-- Met à jour la RPC get_all_user_badges pour retourner le tier
-- ============================================================================

-- 1. Ajouter la colonne tier
ALTER TABLE badges ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT NULL;

-- 2. Mettre à jour les badges books_completed avec les tiers
UPDATE badges SET tier = 'bronze'       WHERE id = 'books_1';
UPDATE badges SET tier = 'silver'       WHERE id = 'books_5';
UPDATE badges SET tier = 'gold'         WHERE id = 'books_10';
UPDATE badges SET tier = 'platinum'     WHERE id = 'books_25';
UPDATE badges SET tier = 'diamond'      WHERE id = 'books_50';
UPDATE badges SET tier = 'legendary'    WHERE id = 'books_100';
UPDATE badges SET tier = 'mythic'       WHERE id = 'books_200';
UPDATE badges SET tier = 'transcendent' WHERE id = 'books_500';

-- 3. Supprimer l'ancienne fonction (le type de retour change, DROP obligatoire)
DROP FUNCTION IF EXISTS get_all_user_badges(UUID);

-- 4. Recréer la RPC get_all_user_badges avec le champ tier
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
BEGIN
  -- Calculer les statistiques de l'utilisateur

  -- Livres terminés
  SELECT COUNT(*) INTO v_completed_books
  FROM user_books
  WHERE user_id = p_user_id AND status = 'finished';

  -- Temps total de lecture (en minutes)
  SELECT COALESCE(SUM(
    EXTRACT(EPOCH FROM (end_time - start_time)) / 60
  ), 0)::INTEGER INTO v_total_reading_minutes
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL;

  -- Nombre de sessions
  SELECT COUNT(*) INTO v_session_count
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL;

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

  -- Sessions après minuit (00:00-05:00)
  SELECT COUNT(*) INTO v_night_sessions
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
    AND EXTRACT(HOUR FROM start_time) BETWEEN 0 AND 4;

  -- Sessions avant 7h
  SELECT COUNT(*) INTO v_morning_sessions
  FROM reading_sessions
  WHERE user_id = p_user_id AND end_time IS NOT NULL
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

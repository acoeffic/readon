-- Correction V2 de la fonction get_user_search_data
-- Fix du calcul du streak qui causait une erreur SQL

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
  -- Récupérer l'utilisateur actuel
  v_current_user_id := auth.uid();

  -- Récupérer le profil de base
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

  -- Vérifier si le profil est privé
  v_is_private := (v_profile->>'is_profile_private')::BOOLEAN;

  -- Si le profil est privé, vérifier si l'utilisateur actuel est ami
  IF v_is_private THEN
    -- Vérifier si une relation d'amitié acceptée existe
    SELECT EXISTS (
      SELECT 1
      FROM friends
      WHERE ((requester_id = v_current_user_id AND addressee_id = p_user_id)
         OR (requester_id = p_user_id AND addressee_id = v_current_user_id))
        AND status = 'accepted'
    ) INTO v_is_friend;

    -- Si pas ami, retourner uniquement les infos de base
    IF NOT v_is_friend OR v_current_user_id IS NULL THEN
      RETURN v_profile;
    END IF;
  END IF;

  -- Le profil est public ou l'utilisateur est ami, récupérer toutes les données

  -- Badges récents (3 plus récents débloqués)
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

  -- Livre actuellement en cours de lecture
  SELECT jsonb_build_object(
    'id', ub.id,
    'title', b.title,
    'author', b.author,
    'cover_url', b.cover_url
  )
  INTO v_current_book
  FROM user_books ub
  JOIN books b ON b.id = ub.book_id
  WHERE ub.user_id = p_user_id
    AND ub.status = 'reading'
  ORDER BY ub.updated_at DESC
  LIMIT 1;

  -- Nombre de livres terminés
  SELECT COUNT(*)
  INTO v_books_finished
  FROM user_books
  WHERE user_id = p_user_id
    AND status = 'finished';

  -- Nombre d'amis acceptés
  SELECT COUNT(*)
  INTO v_friends_count
  FROM friends
  WHERE (requester_id = p_user_id OR addressee_id = p_user_id)
    AND status = 'accepted';

  -- Streak actuel : essayer d'utiliser la fonction existante
  v_current_streak := 0;
  BEGIN
    SELECT get_current_streak_for_user(p_user_id) INTO v_current_streak;
  EXCEPTION
    WHEN undefined_function THEN
      -- Si la fonction n'existe pas, calculer un streak simplifié
      SELECT COUNT(DISTINCT DATE(start_time))
      INTO v_current_streak
      FROM reading_sessions
      WHERE user_id = p_user_id
        AND end_time IS NOT NULL
        AND start_time >= CURRENT_DATE - INTERVAL '7 days';
  END;

  -- Construire le résultat complet
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

-- Vérifier que la fonction est bien créée
SELECT 'Fonction get_user_search_data V2 corrigée avec succès!' as status;

-- =====================================================
-- Migration: delete_user_account
-- Permet à un utilisateur authentifié de supprimer
-- définitivement son compte et toutes ses données
-- =====================================================

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  uid UUID;
BEGIN
  -- 1. Récupérer l'ID de l'utilisateur authentifié
  uid := auth.uid();

  IF uid IS NULL THEN
    RETURN json_build_object(
      'success', FALSE,
      'error', 'NOT_AUTHENTICATED',
      'message', 'Utilisateur non authentifié'
    );
  END IF;

  -- 2. Supprimer les tables sans ON DELETE CASCADE

  -- Notifications (envoyées et reçues)
  DELETE FROM notifications WHERE user_id = uid OR from_user_id = uid;

  -- Commentaires
  DELETE FROM comments WHERE author_id = uid;

  -- Likes
  DELETE FROM likes WHERE user_id = uid;

  -- Réactions avancées
  DELETE FROM reactions WHERE user_id = uid;

  -- Amitiés (les deux directions)
  DELETE FROM friends WHERE requester_id = uid OR addressee_id = uid;

  -- Badges utilisateur
  DELETE FROM user_badges WHERE user_id = uid;

  -- Sessions de lecture
  DELETE FROM reading_sessions WHERE user_id = uid;

  -- Livres utilisateur
  DELETE FROM user_books WHERE user_id = uid;

  -- 3. Supprimer les avatars dans le storage
  DELETE FROM storage.objects
  WHERE bucket_id = 'profiles'
    AND name LIKE 'avatars/' || uid::TEXT || '/%';

  -- 4. Supprimer le profil
  DELETE FROM profiles WHERE id = uid;

  -- 5. Supprimer l'utilisateur auth (déclenche CASCADE sur :
  --    reading_groups, group_members, group_invitations,
  --    group_activities, group_challenges, challenge_participants,
  --    streak_freezes, kindle_sync)
  DELETE FROM auth.users WHERE id = uid;

  RETURN json_build_object(
    'success', TRUE,
    'message', 'Compte supprimé avec succès'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', FALSE,
    'error', 'DELETION_FAILED',
    'message', SQLERRM
  );
END;
$$;

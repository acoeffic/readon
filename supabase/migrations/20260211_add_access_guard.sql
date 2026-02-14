-- Migration : Fonction de vérification d'accès aux données utilisateur
-- Utilisée par le client pour vérifier si l'utilisateur courant peut
-- accéder aux données d'un autre utilisateur (badges, flow, frozen dates).

CREATE OR REPLACE FUNCTION can_access_user_data(p_target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID := auth.uid();
BEGIN
  -- Non authentifié → refusé
  IF v_current_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Soi-même → toujours autorisé
  IF v_current_user_id = p_target_user_id THEN
    RETURN TRUE;
  END IF;

  -- Ami accepté → autorisé
  IF EXISTS (
    SELECT 1 FROM friends
    WHERE status = 'accepted'
      AND (
        (requester_id = v_current_user_id AND addressee_id = p_target_user_id)
        OR (requester_id = p_target_user_id AND addressee_id = v_current_user_id)
      )
  ) THEN
    RETURN TRUE;
  END IF;

  -- Profil public → autorisé
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_target_user_id
      AND COALESCE(is_profile_private, FALSE) = FALSE
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

-- Accessible uniquement aux utilisateurs authentifiés
GRANT EXECUTE ON FUNCTION can_access_user_data(UUID) TO authenticated;

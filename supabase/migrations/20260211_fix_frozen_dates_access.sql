-- Migration : Sécuriser get_frozen_dates
-- Ajouter une vérification d'accès quand p_user_id est fourni.
-- Un utilisateur ne peut voir les frozen dates que pour lui-même
-- ou pour un ami accepté / profil public.

CREATE OR REPLACE FUNCTION get_frozen_dates(p_user_id UUID DEFAULT NULL)
RETURNS DATE[] AS $$
DECLARE
  target_user_id UUID;
  frozen_dates DATE[];
BEGIN
  target_user_id := COALESCE(p_user_id, auth.uid());

  -- Si on demande les données d'un autre utilisateur, vérifier l'accès
  IF target_user_id != auth.uid() THEN
    IF NOT can_access_user_data(target_user_id) THEN
      RETURN ARRAY[]::DATE[];
    END IF;
  END IF;

  SELECT ARRAY_AGG(frozen_date ORDER BY frozen_date DESC)
  INTO frozen_dates
  FROM streak_freezes
  WHERE user_id = target_user_id;

  RETURN COALESCE(frozen_dates, ARRAY[]::DATE[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

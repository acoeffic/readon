-- Migration : Supprimer sync_client_premium_status
-- Cette RPC permet au client de se déclarer premium sans vérification serveur.
-- Le statut premium doit uniquement être mis à jour par le webhook RevenueCat
-- (service_role), jamais par le client (authenticated).

-- =====================================================
-- 1. DROP la fonction vulnérable
-- =====================================================
DROP FUNCTION IF EXISTS sync_client_premium_status(BOOLEAN, TIMESTAMPTZ, TEXT);

-- =====================================================
-- 2. DENY explicite : aucun write direct sur subscriptions
--    RLS est déjà activé avec seulement une SELECT policy,
--    mais on ajoute des policies explicites pour la clarté
--    et pour éviter qu'un futur ALTER les ouvre par erreur.
-- =====================================================
DROP POLICY IF EXISTS "Block direct inserts from authenticated" ON subscriptions;
CREATE POLICY "Block direct inserts from authenticated"
  ON subscriptions FOR INSERT TO authenticated
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS "Block direct updates from authenticated" ON subscriptions;
CREATE POLICY "Block direct updates from authenticated"
  ON subscriptions FOR UPDATE TO authenticated
  USING (FALSE) WITH CHECK (FALSE);

DROP POLICY IF EXISTS "Block direct deletes from authenticated" ON subscriptions;
CREATE POLICY "Block direct deletes from authenticated"
  ON subscriptions FOR DELETE TO authenticated
  USING (FALSE);

-- =====================================================
-- 3. Corriger les fonctions existantes : SET search_path
-- =====================================================
CREATE OR REPLACE FUNCTION is_user_premium(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
  target_user UUID;
  sub_status TEXT;
  sub_expires TIMESTAMPTZ;
BEGIN
  target_user := COALESCE(p_user_id, auth.uid());

  SELECT status, expires_at
  INTO sub_status, sub_expires
  FROM subscriptions
  WHERE user_id = target_user;

  IF NOT FOUND THEN RETURN FALSE; END IF;

  IF sub_status IN ('premium', 'trial') THEN
    IF sub_expires IS NULL OR sub_expires > NOW() THEN
      RETURN TRUE;
    END IF;
  END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION check_premium_status()
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_is_premium BOOLEAN := FALSE;
  v_premium_until TIMESTAMPTZ;
  v_sub_status TEXT;
  v_sub_expires TIMESTAMPTZ;
BEGIN
  SELECT status, expires_at
  INTO v_sub_status, v_sub_expires
  FROM subscriptions
  WHERE user_id = auth.uid();

  IF FOUND AND v_sub_status IN ('premium', 'trial') THEN
    IF v_sub_expires IS NULL OR v_sub_expires > NOW() THEN
      v_is_premium := TRUE;
      v_premium_until := v_sub_expires;
    ELSE
      UPDATE profiles SET is_premium = FALSE WHERE id = auth.uid();
      v_is_premium := FALSE;
      v_premium_until := v_sub_expires;
    END IF;
  ELSE
    SELECT is_premium, premium_until
    INTO v_is_premium, v_premium_until
    FROM profiles WHERE id = auth.uid();

    IF v_is_premium AND v_premium_until IS NOT NULL AND v_premium_until < NOW() THEN
      UPDATE profiles SET is_premium = FALSE WHERE id = auth.uid();
      v_is_premium := FALSE;
    END IF;
  END IF;

  SELECT json_build_object(
    'is_premium', COALESCE(v_is_premium, FALSE),
    'premium_until', v_premium_until,
    'status', COALESCE(v_sub_status, CASE WHEN v_is_premium THEN 'premium' ELSE 'free' END)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

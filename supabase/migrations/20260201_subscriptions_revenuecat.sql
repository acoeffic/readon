-- =====================================================
-- Migration: Subscriptions RevenueCat
-- Table subscriptions, RLS, fonctions de vérification,
-- sync client-side, backfill depuis profiles
-- =====================================================

-- =====================================================
-- 1. TABLE SUBSCRIPTIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS subscriptions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'free'
                  CHECK (status IN ('free', 'trial', 'premium', 'expired', 'billing_issue')),
  platform      TEXT CHECK (platform IN ('ios', 'android', NULL)),
  product_id    TEXT,
  rc_customer_id TEXT,
  original_purchase_date TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ,
  auto_renew    BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status) WHERE status IN ('premium', 'trial');
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires ON subscriptions(expires_at) WHERE expires_at IS NOT NULL;

-- =====================================================
-- 2. RLS POLICIES
-- Users can only SELECT their own subscription.
-- No INSERT/UPDATE/DELETE policy for authenticated role
-- → only service_role (webhook) can write.
-- =====================================================
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own subscription"
  ON subscriptions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- 3. FUNCTION: is_user_premium
-- Vérification serveur du statut premium
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
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- =====================================================
-- 4. FUNCTION: sync_client_premium_status
-- Fallback client-side pour sync depuis le SDK RevenueCat
-- =====================================================
CREATE OR REPLACE FUNCTION sync_client_premium_status(
  p_is_premium BOOLEAN,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_product_id TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO subscriptions (user_id, status, expires_at, product_id, updated_at)
  VALUES (
    auth.uid(),
    CASE WHEN p_is_premium THEN 'premium' ELSE 'free' END,
    p_expires_at,
    p_product_id,
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    status = CASE WHEN p_is_premium THEN 'premium' ELSE subscriptions.status END,
    expires_at = COALESCE(p_expires_at, subscriptions.expires_at),
    product_id = COALESCE(p_product_id, subscriptions.product_id),
    updated_at = NOW();

  -- Sync le cache profiles
  UPDATE profiles SET
    is_premium = p_is_premium,
    premium_until = p_expires_at
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. UPDATE check_premium_status (existant)
-- Checker subscriptions d'abord, fallback profiles
-- =====================================================
CREATE OR REPLACE FUNCTION check_premium_status()
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_is_premium BOOLEAN := FALSE;
  v_premium_until TIMESTAMPTZ;
  v_sub_status TEXT;
  v_sub_expires TIMESTAMPTZ;
BEGIN
  -- Vérifier la table subscriptions d'abord
  SELECT status, expires_at
  INTO v_sub_status, v_sub_expires
  FROM subscriptions
  WHERE user_id = auth.uid();

  IF FOUND AND v_sub_status IN ('premium', 'trial') THEN
    IF v_sub_expires IS NULL OR v_sub_expires > NOW() THEN
      v_is_premium := TRUE;
      v_premium_until := v_sub_expires;
    ELSE
      -- Expiré : mettre à jour le cache profiles
      UPDATE profiles SET is_premium = FALSE WHERE id = auth.uid();
      v_is_premium := FALSE;
      v_premium_until := v_sub_expires;
    END IF;
  ELSE
    -- Fallback sur les colonnes legacy de profiles
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. BACKFILL : créer les lignes subscription
--    pour les utilisateurs existants
-- =====================================================
INSERT INTO subscriptions (user_id, status, expires_at)
SELECT
  id,
  CASE
    WHEN is_premium AND (premium_until IS NULL OR premium_until > NOW()) THEN 'premium'
    ELSE 'free'
  END,
  premium_until
FROM profiles
ON CONFLICT (user_id) DO NOTHING;

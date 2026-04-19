-- =====================================================
-- Migration: Streak Freeze V2 (Free/Premium split)
-- Passe de 1 freeze/semaine pour tous à :
--   Gratuit : 2 auto-freezes/mois, 1 jour consécutif max, pas de freeze manuel
--   Premium : auto-freezes illimités, 2 jours consécutifs max, freeze manuel
-- =====================================================

-- =====================================================
-- 1. SCHEMA : Ajouter month_start
-- =====================================================

ALTER TABLE streak_freezes
ADD COLUMN IF NOT EXISTS month_start DATE;

-- Backfill month_start depuis frozen_date
UPDATE streak_freezes
SET month_start = date_trunc('month', frozen_date)::DATE
WHERE month_start IS NULL;

-- Rendre NOT NULL après backfill
ALTER TABLE streak_freezes
ALTER COLUMN month_start SET NOT NULL;

ALTER TABLE streak_freezes
ALTER COLUMN month_start SET DEFAULT date_trunc('month', CURRENT_DATE)::DATE;

-- Index pour comptage mensuel
CREATE INDEX IF NOT EXISTS idx_streak_freezes_user_month
ON streak_freezes(user_id, month_start);

-- =====================================================
-- 2. REMPLACER get_freeze_status()
-- Retourne le statut freeze adapté free/premium
-- =====================================================

CREATE OR REPLACE FUNCTION get_freeze_status()
RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_month_start DATE;
  v_auto_freezes_this_month INT;
  v_auto_freeze_limit INT;
  v_auto_freezes_remaining INT;
  v_can_manual_freeze BOOLEAN;
  v_last_freeze_date DATE;
  v_consecutive_frozen INT;
  v_max_consecutive INT;
  v_can_freeze BOOLEAN;
  v_check_date DATE;
  result JSON;
BEGIN
  -- Déterminer le statut premium
  v_is_premium := is_user_premium(auth.uid());

  -- Début du mois courant
  v_month_start := date_trunc('month', CURRENT_DATE)::DATE;

  -- Compter les auto-freezes utilisés ce mois
  SELECT COUNT(*) INTO v_auto_freezes_this_month
  FROM streak_freezes
  WHERE user_id = auth.uid()
    AND month_start = v_month_start
    AND is_auto = TRUE;

  -- Limites selon le tier
  IF v_is_premium THEN
    v_auto_freeze_limit := -1; -- illimité
    v_can_manual_freeze := TRUE;
    v_max_consecutive := 2;
  ELSE
    v_auto_freeze_limit := 2;
    v_can_manual_freeze := FALSE;
    v_max_consecutive := 1;
  END IF;

  -- Calcul des auto-freezes restants
  IF v_auto_freeze_limit = -1 THEN
    v_auto_freezes_remaining := -1; -- illimité
  ELSE
    v_auto_freezes_remaining := GREATEST(0, v_auto_freeze_limit - v_auto_freezes_this_month);
  END IF;

  -- Dernier freeze utilisé
  SELECT frozen_date INTO v_last_freeze_date
  FROM streak_freezes
  WHERE user_id = auth.uid()
  ORDER BY frozen_date DESC
  LIMIT 1;

  -- Compter les jours consécutifs frozen en remontant depuis hier
  v_consecutive_frozen := 0;
  v_check_date := CURRENT_DATE - INTERVAL '1 day';

  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM streak_freezes
      WHERE user_id = auth.uid()
        AND frozen_date = v_check_date
    );
    v_consecutive_frozen := v_consecutive_frozen + 1;
    v_check_date := v_check_date - INTERVAL '1 day';
  END LOOP;

  -- Peut-on freeze ? (quota dispo ET limite consécutive non atteinte)
  v_can_freeze := (v_auto_freezes_remaining > 0 OR v_auto_freezes_remaining = -1)
                  AND v_consecutive_frozen < v_max_consecutive;

  SELECT json_build_object(
    'is_premium', v_is_premium,
    'can_freeze', v_can_freeze,
    'can_manual_freeze', v_can_manual_freeze,
    'auto_freezes_this_month', v_auto_freezes_this_month,
    'auto_freeze_limit', v_auto_freeze_limit,
    'auto_freezes_remaining', v_auto_freezes_remaining,
    'consecutive_frozen_days', v_consecutive_frozen,
    'max_consecutive', v_max_consecutive,
    'last_freeze_date', v_last_freeze_date,
    'month_start', v_month_start
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 3. REMPLACER use_streak_freeze()
-- Nouvelles validations : premium, mensuel, consécutif
-- =====================================================

CREATE OR REPLACE FUNCTION use_streak_freeze(
  p_frozen_date DATE DEFAULT NULL,
  p_is_auto BOOLEAN DEFAULT FALSE
)
RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_target_date DATE;
  v_month_start DATE;
  v_week_start DATE;
  v_auto_freezes_this_month INT;
  v_consecutive_frozen INT;
  v_max_consecutive INT;
  v_already_frozen BOOLEAN;
  v_check_date DATE;
  result JSON;
BEGIN
  v_is_premium := is_user_premium(auth.uid());
  v_target_date := COALESCE(p_frozen_date, CURRENT_DATE - INTERVAL '1 day');
  v_month_start := date_trunc('month', v_target_date)::DATE;
  v_week_start := date_trunc('week', v_target_date)::DATE;

  -- REGLE 1 : Freeze manuel réservé aux premium
  IF NOT p_is_auto AND NOT v_is_premium THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'MANUAL_FREEZE_PREMIUM_ONLY',
      'message', 'Le freeze manuel est réservé aux utilisateurs Premium'
    ) INTO result;
    RETURN result;
  END IF;

  -- REGLE 2 : Pas de date future
  IF v_target_date > CURRENT_DATE THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'INVALID_DATE',
      'message', 'Impossible de freeze une date future'
    ) INTO result;
    RETURN result;
  END IF;

  -- REGLE 3 : Pas plus de 7 jours
  IF v_target_date < CURRENT_DATE - INTERVAL '7 days' THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'DATE_TOO_OLD',
      'message', 'Impossible de freeze une date de plus de 7 jours'
    ) INTO result;
    RETURN result;
  END IF;

  -- REGLE 4 : Date pas déjà frozen
  SELECT EXISTS (
    SELECT 1 FROM streak_freezes
    WHERE user_id = auth.uid()
      AND frozen_date = v_target_date
  ) INTO v_already_frozen;

  IF v_already_frozen THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'DATE_ALREADY_FROZEN',
      'message', 'Cette date est déjà protégée'
    ) INTO result;
    RETURN result;
  END IF;

  -- REGLE 5 : Limite mensuelle auto-freeze (users gratuits uniquement)
  IF p_is_auto AND NOT v_is_premium THEN
    SELECT COUNT(*) INTO v_auto_freezes_this_month
    FROM streak_freezes
    WHERE user_id = auth.uid()
      AND month_start = v_month_start
      AND is_auto = TRUE;

    IF v_auto_freezes_this_month >= 2 THEN
      SELECT json_build_object(
        'success', FALSE,
        'error', 'MONTHLY_LIMIT_REACHED',
        'message', 'Tu as utilisé tes 2 auto-freezes ce mois-ci'
      ) INTO result;
      RETURN result;
    END IF;
  END IF;

  -- REGLE 6 : Limite de jours consécutifs
  v_consecutive_frozen := 0;
  v_check_date := v_target_date - INTERVAL '1 day';

  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM streak_freezes
      WHERE user_id = auth.uid()
        AND frozen_date = v_check_date
    );
    v_consecutive_frozen := v_consecutive_frozen + 1;
    v_check_date := v_check_date - INTERVAL '1 day';
  END LOOP;

  IF v_is_premium THEN
    v_max_consecutive := 2;
  ELSE
    v_max_consecutive := 1;
  END IF;

  -- consecutive_frozen = jours frozen AVANT target.
  -- Si on freeze target, le total sera consecutive_frozen + 1.
  -- On bloque si consecutive_frozen >= max_consecutive.
  IF v_consecutive_frozen >= v_max_consecutive THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'CONSECUTIVE_LIMIT_REACHED',
      'message', format('Maximum %s jour(s) consécutif(s) de freeze atteint', v_max_consecutive)
    ) INTO result;
    RETURN result;
  END IF;

  -- Toutes les vérifications passées, créer le freeze
  INSERT INTO streak_freezes (user_id, frozen_date, week_start, month_start, is_auto)
  VALUES (auth.uid(), v_target_date, v_week_start, v_month_start, p_is_auto);

  SELECT json_build_object(
    'success', TRUE,
    'frozen_date', v_target_date,
    'message', 'Streak protégé pour le ' || to_char(v_target_date, 'DD/MM/YYYY')
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. FONCTION INTERNE : _auto_freeze_for_user
-- Applique un auto-freeze pour un user spécifique
-- (appelée par le batch, pas exposée en RPC)
-- =====================================================

CREATE OR REPLACE FUNCTION _auto_freeze_for_user(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_target_date DATE;
  v_month_start DATE;
  v_week_start DATE;
  v_auto_freezes_this_month INT;
  v_consecutive_frozen INT;
  v_max_consecutive INT;
  v_has_read_yesterday BOOLEAN;
  v_has_active_streak BOOLEAN;
  v_already_frozen BOOLEAN;
  v_check_date DATE;
BEGIN
  v_target_date := CURRENT_DATE - INTERVAL '1 day';
  v_month_start := date_trunc('month', v_target_date)::DATE;
  v_week_start := date_trunc('week', v_target_date)::DATE;
  v_is_premium := is_user_premium(p_user_id);

  -- L'user a-t-il lu hier ? Si oui, pas besoin de freeze
  SELECT EXISTS (
    SELECT 1 FROM reading_sessions
    WHERE user_id = p_user_id
      AND end_time IS NOT NULL
      AND end_time::date = v_target_date
  ) INTO v_has_read_yesterday;

  IF v_has_read_yesterday THEN
    RETURN json_build_object('success', FALSE, 'reason', 'USER_READ_YESTERDAY');
  END IF;

  -- L'user a-t-il un streak actif ? (session ou freeze dans les 7 derniers jours avant hier)
  SELECT EXISTS (
    SELECT 1 FROM reading_sessions
    WHERE user_id = p_user_id
      AND end_time IS NOT NULL
      AND end_time::date >= CURRENT_DATE - INTERVAL '7 days'
      AND end_time::date < v_target_date
    UNION ALL
    SELECT 1 FROM streak_freezes
    WHERE user_id = p_user_id
      AND frozen_date >= CURRENT_DATE - INTERVAL '7 days'
      AND frozen_date < v_target_date
  ) INTO v_has_active_streak;

  IF NOT v_has_active_streak THEN
    RETURN json_build_object('success', FALSE, 'reason', 'NO_ACTIVE_STREAK');
  END IF;

  -- Date déjà frozen ?
  SELECT EXISTS (
    SELECT 1 FROM streak_freezes
    WHERE user_id = p_user_id AND frozen_date = v_target_date
  ) INTO v_already_frozen;

  IF v_already_frozen THEN
    RETURN json_build_object('success', FALSE, 'reason', 'ALREADY_FROZEN');
  END IF;

  -- Limite mensuelle (gratuits : 2/mois, premium : illimité)
  IF NOT v_is_premium THEN
    SELECT COUNT(*) INTO v_auto_freezes_this_month
    FROM streak_freezes
    WHERE user_id = p_user_id
      AND month_start = v_month_start
      AND is_auto = TRUE;

    IF v_auto_freezes_this_month >= 2 THEN
      RETURN json_build_object('success', FALSE, 'reason', 'MONTHLY_LIMIT_REACHED');
    END IF;
  END IF;

  -- Limite consécutive
  v_consecutive_frozen := 0;
  v_check_date := v_target_date - INTERVAL '1 day';

  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM streak_freezes
      WHERE user_id = p_user_id AND frozen_date = v_check_date
    );
    v_consecutive_frozen := v_consecutive_frozen + 1;
    v_check_date := v_check_date - INTERVAL '1 day';
  END LOOP;

  v_max_consecutive := CASE WHEN v_is_premium THEN 2 ELSE 1 END;

  IF v_consecutive_frozen >= v_max_consecutive THEN
    RETURN json_build_object('success', FALSE, 'reason', 'CONSECUTIVE_LIMIT');
  END IF;

  -- Insérer l'auto-freeze
  INSERT INTO streak_freezes (user_id, frozen_date, week_start, month_start, is_auto)
  VALUES (p_user_id, v_target_date, v_week_start, v_month_start, TRUE);

  RETURN json_build_object('success', TRUE, 'frozen_date', v_target_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. FONCTION BATCH : auto_freeze_all_users
-- Appelée par pg_cron chaque nuit
-- =====================================================

CREATE OR REPLACE FUNCTION auto_freeze_all_users()
RETURNS JSON AS $$
DECLARE
  v_user RECORD;
  v_result JSON;
  v_success_count INT := 0;
  v_skip_count INT := 0;
  v_error_count INT := 0;
BEGIN
  -- Itérer sur les users ayant des sessions récentes (30 jours)
  FOR v_user IN
    SELECT DISTINCT rs.user_id
    FROM reading_sessions rs
    WHERE rs.end_time IS NOT NULL
      AND rs.end_time::date >= CURRENT_DATE - INTERVAL '30 days'
  LOOP
    BEGIN
      v_result := _auto_freeze_for_user(v_user.user_id);
      IF (v_result->>'success')::boolean THEN
        v_success_count := v_success_count + 1;
      ELSE
        v_skip_count := v_skip_count + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
    END;
  END LOOP;

  RETURN json_build_object(
    'success_count', v_success_count,
    'skip_count', v_skip_count,
    'error_count', v_error_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. CRON : auto-freeze quotidien à 01:00 UTC
-- NOTE: Nécessite pg_cron activé sur le projet Supabase
-- Décommenter et exécuter manuellement si pg_cron est dispo
-- =====================================================

-- SELECT cron.schedule(
--   'auto-freeze-streaks-daily',
--   '0 1 * * *',
--   $$ SELECT auto_freeze_all_users(); $$
-- );

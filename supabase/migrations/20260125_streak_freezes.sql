-- =====================================================
-- Migration: Streak Freezes (Protection de streak)
-- Permet aux utilisateurs de protéger leur streak 1x/semaine
-- =====================================================

-- Table pour stocker les freezes utilisés
CREATE TABLE IF NOT EXISTS streak_freezes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  frozen_date DATE NOT NULL, -- Le jour qui a été "protégé"
  week_start DATE NOT NULL,  -- Début de la semaine (pour limiter 1/semaine)
  is_auto BOOLEAN NOT NULL DEFAULT FALSE, -- True si déclenché automatiquement (premium)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour recherche rapide par utilisateur et semaine
CREATE INDEX IF NOT EXISTS idx_streak_freezes_user_week
ON streak_freezes(user_id, week_start);

-- Index pour recherche par date frozen
CREATE INDEX IF NOT EXISTS idx_streak_freezes_user_date
ON streak_freezes(user_id, frozen_date);

-- Enable RLS
ALTER TABLE streak_freezes ENABLE ROW LEVEL SECURITY;

-- Politique: Les utilisateurs ne voient que leurs propres freezes
CREATE POLICY "Users can view own freezes"
ON streak_freezes FOR SELECT
USING (auth.uid() = user_id);

-- Politique: Les utilisateurs peuvent créer leurs propres freezes
CREATE POLICY "Users can insert own freezes"
ON streak_freezes FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- RPC: get_freeze_status
-- Retourne le statut du freeze pour l'utilisateur courant
-- =====================================================
CREATE OR REPLACE FUNCTION get_freeze_status()
RETURNS JSON AS $$
DECLARE
  current_week_start DATE;
  freeze_used_this_week BOOLEAN;
  last_freeze_date DATE;
  result JSON;
BEGIN
  -- Calculer le début de la semaine courante (Lundi)
  current_week_start := date_trunc('week', CURRENT_DATE)::DATE;

  -- Vérifier si un freeze a été utilisé cette semaine
  SELECT EXISTS (
    SELECT 1 FROM streak_freezes
    WHERE user_id = auth.uid()
    AND week_start = current_week_start
  ) INTO freeze_used_this_week;

  -- Récupérer la date du dernier freeze utilisé
  SELECT frozen_date INTO last_freeze_date
  FROM streak_freezes
  WHERE user_id = auth.uid()
  ORDER BY used_at DESC
  LIMIT 1;

  SELECT json_build_object(
    'freeze_available', NOT freeze_used_this_week,
    'freeze_used_this_week', freeze_used_this_week,
    'last_freeze_date', last_freeze_date,
    'week_start', current_week_start,
    'week_end', current_week_start + INTERVAL '6 days'
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- RPC: use_streak_freeze
-- Utilise un freeze pour protéger un jour spécifique
-- Retourne success/error avec message
-- =====================================================
CREATE OR REPLACE FUNCTION use_streak_freeze(p_frozen_date DATE DEFAULT NULL, p_is_auto BOOLEAN DEFAULT FALSE)
RETURNS JSON AS $$
DECLARE
  current_week_start DATE;
  target_date DATE;
  freeze_exists BOOLEAN;
  result JSON;
BEGIN
  -- Date à protéger (par défaut: hier)
  target_date := COALESCE(p_frozen_date, CURRENT_DATE - INTERVAL '1 day');

  -- Calculer le début de la semaine de la date cible
  current_week_start := date_trunc('week', target_date)::DATE;

  -- Vérifier si un freeze existe déjà cette semaine
  SELECT EXISTS (
    SELECT 1 FROM streak_freezes
    WHERE user_id = auth.uid()
    AND week_start = current_week_start
  ) INTO freeze_exists;

  IF freeze_exists THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'FREEZE_ALREADY_USED',
      'message', 'Vous avez déjà utilisé votre freeze cette semaine'
    ) INTO result;
    RETURN result;
  END IF;

  -- Vérifier que la date n'est pas dans le futur
  IF target_date > CURRENT_DATE THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'INVALID_DATE',
      'message', 'Impossible de freeze une date future'
    ) INTO result;
    RETURN result;
  END IF;

  -- Vérifier que la date n'est pas trop ancienne (max 7 jours)
  IF target_date < CURRENT_DATE - INTERVAL '7 days' THEN
    SELECT json_build_object(
      'success', FALSE,
      'error', 'DATE_TOO_OLD',
      'message', 'Impossible de freeze une date de plus de 7 jours'
    ) INTO result;
    RETURN result;
  END IF;

  -- Créer le freeze
  INSERT INTO streak_freezes (user_id, frozen_date, week_start, is_auto)
  VALUES (auth.uid(), target_date, current_week_start, p_is_auto);

  SELECT json_build_object(
    'success', TRUE,
    'frozen_date', target_date,
    'message', 'Streak protégé pour le ' || to_char(target_date, 'DD/MM/YYYY')
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- RPC: get_frozen_dates
-- Retourne toutes les dates frozen pour un utilisateur
-- (utilisé dans le calcul du streak)
-- =====================================================
CREATE OR REPLACE FUNCTION get_frozen_dates(p_user_id UUID DEFAULT NULL)
RETURNS DATE[] AS $$
DECLARE
  target_user_id UUID;
  frozen_dates DATE[];
BEGIN
  target_user_id := COALESCE(p_user_id, auth.uid());

  SELECT ARRAY_AGG(frozen_date ORDER BY frozen_date DESC)
  INTO frozen_dates
  FROM streak_freezes
  WHERE user_id = target_user_id;

  RETURN COALESCE(frozen_dates, ARRAY[]::DATE[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

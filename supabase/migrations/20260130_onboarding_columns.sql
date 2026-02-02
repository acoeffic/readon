-- =====================================================
-- Migration: onboarding columns
-- =====================================================
-- Ajoute les colonnes pour le flow d'onboarding premiere connexion

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS reading_habit TEXT;
-- Valeurs possibles : 'liseuse', 'papier', 'mix'

-- Les comptes existants ont deja utilise l'app, ne pas leur montrer l'onboarding
UPDATE profiles
SET onboarding_completed = TRUE
WHERE onboarding_completed = FALSE;

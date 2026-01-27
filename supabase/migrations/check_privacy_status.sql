-- Script pour vérifier le statut de confidentialité des utilisateurs
-- À exécuter dans l'éditeur SQL de Supabase

-- 1. Vérifier si la colonne existe
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name = 'is_profile_private';

-- 2. Vérifier les valeurs des utilisateurs
SELECT
  id,
  display_name,
  email,
  is_profile_private,
  created_at
FROM profiles
ORDER BY created_at DESC
LIMIT 10;

-- 3. Compter les profils publics vs privés
SELECT
  is_profile_private,
  COUNT(*) as count
FROM profiles
GROUP BY is_profile_private;

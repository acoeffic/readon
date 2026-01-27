-- Script de debug complet pour identifier le problème avec Charles
-- Exécutez ce script dans l'éditeur SQL de Supabase

-- 1. Trouver Charles et vérifier sa valeur is_profile_private dans la DB
SELECT
  id,
  display_name,
  email,
  is_profile_private,
  created_at
FROM profiles
WHERE display_name ILIKE '%charles%' OR email ILIKE '%charles%'
LIMIT 5;

-- 2. Vérifier le type de la colonne is_profile_private
SELECT
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name = 'is_profile_private';

-- 3. Tester la fonction get_user_search_data avec l'UUID de Charles
-- REMPLACEZ 'UUID-DE-CHARLES' par le vrai UUID trouvé à l'étape 1
-- SELECT get_user_search_data('UUID-DE-CHARLES');

-- Exemple : Si Charles a l'UUID '12345678-1234-1234-1234-123456789abc'
-- Décommentez et remplacez :
-- SELECT get_user_search_data('12345678-1234-1234-1234-123456789abc');

-- 4. Vérifier la valeur retournée par COALESCE
-- SELECT COALESCE(is_profile_private, FALSE) as coalesced_value
-- FROM profiles
-- WHERE id = 'UUID-DE-CHARLES';

-- 5. Vérifier s'il y a des données nulles
SELECT
  COUNT(*) as total_users,
  COUNT(is_profile_private) as non_null_count,
  COUNT(*) - COUNT(is_profile_private) as null_count
FROM profiles;

-- 6. Distribution des valeurs de is_profile_private
SELECT
  is_profile_private,
  COUNT(*) as count
FROM profiles
GROUP BY is_profile_private;

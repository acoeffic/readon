-- Script de test pour vérifier les données de Charles

-- 1. Trouver l'ID de Charles
SELECT id, display_name, email, is_profile_private, created_at
FROM profiles
WHERE display_name ILIKE '%charles%' OR email ILIKE '%charles%'
LIMIT 5;

-- 2. Tester la fonction get_user_search_data avec l'ID de Charles
-- REMPLACEZ 'l-id-de-charles-ici' par le vrai UUID de Charles trouvé ci-dessus
-- SELECT get_user_search_data('l-id-de-charles-ici');

-- Exemple : Si l'ID de Charles est 12345678-1234-1234-1234-123456789abc
-- SELECT get_user_search_data('12345678-1234-1234-1234-123456789abc');

-- 3. Vérifier ses badges
-- SELECT * FROM user_badges WHERE user_id = 'l-id-de-charles-ici';

-- 4. Vérifier ses livres
-- SELECT * FROM user_books WHERE user_id = 'l-id-de-charles-ici';

-- 5. Vérifier ses sessions de lecture
-- SELECT * FROM reading_sessions WHERE user_id = 'l-id-de-charles-ici' LIMIT 5;

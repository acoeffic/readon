-- Vérifier que la fonction get_user_search_data existe
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'get_user_search_data';

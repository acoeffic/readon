-- Vérifier la structure de la table user_badges
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_badges'
ORDER BY ordinal_position;

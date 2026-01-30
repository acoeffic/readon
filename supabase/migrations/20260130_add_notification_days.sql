-- Ajouter la colonne notification_days pour choisir les jours de rappel
-- Stocke un tableau d'entiers 1-7 (1=Lundi, 7=Dimanche)
-- Par défaut tous les jours sont sélectionnés

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notification_days JSONB DEFAULT '[1,2,3,4,5,6,7]'::jsonb;

COMMENT ON COLUMN profiles.notification_days IS 'Jours de la semaine pour les rappels de streak (1=Lundi, 7=Dimanche)';

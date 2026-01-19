-- Migration SQL pour le système de streak de lecture
-- À exécuter dans l'éditeur SQL de Supabase

-- 1. Créer les badges de streak dans la table badges
-- Utilise ON CONFLICT DO NOTHING pour éviter les erreurs si les badges existent déjà
-- La colonne 'requirement' contient le nombre de jours consécutifs requis

INSERT INTO badges (id, name, description, icon, category, requirement, color)
VALUES
  ('streak_1_day', 'Premier Jour', 'Lire 1 jour', '📖', 'streak', 1, '#FFB74D'),
  ('streak_3_days', '3 Jours', 'Lire 3 jours d''affilée', '🔥', 'streak', 3, '#FF9800'),
  ('streak_7_days', 'Une Semaine', 'Lire 7 jours consécutifs', '⭐', 'streak', 7, '#FFC107'),
  ('streak_14_days', '2 Semaines', 'Lire 14 jours consécutifs', '💎', 'streak', 14, '#FF5722'),
  ('streak_30_days', 'Un Mois', 'Lire 30 jours d''affilée', '👑', 'streak', 30, '#9C27B0')
ON CONFLICT (id) DO NOTHING;

-- 2. Vérification : Afficher tous les badges de streak créés
SELECT * FROM badges WHERE category = 'streak' ORDER BY requirement;

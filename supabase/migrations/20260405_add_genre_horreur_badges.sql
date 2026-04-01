-- Migration: Ajout des badges genre Horreur (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_horreur_apprenti', 'Apprenti', 'Lire 5 livres d''horreur', '👻', 'genres', 5, '#4A148C', false, false, 'livres', 29),
  ('genre_horreur_adepte', 'Adepte', 'Lire 15 livres d''horreur', '🧟', 'genres', 15, '#4A148C', false, false, 'livres', 30),
  ('genre_horreur_maitre', 'Maitre', 'Lire 30 livres d''horreur', '🩸', 'genres', 30, '#4A148C', false, false, 'livres', 31),
  ('genre_horreur_legende', 'Légende', 'Lire 50 livres d''horreur', '🏆', 'genres', 50, '#4A148C', false, false, 'livres', 32)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  category = EXCLUDED.category,
  requirement = EXCLUDED.requirement,
  color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium,
  is_secret = EXCLUDED.is_secret,
  progress_unit = EXCLUDED.progress_unit,
  sort_order = EXCLUDED.sort_order;

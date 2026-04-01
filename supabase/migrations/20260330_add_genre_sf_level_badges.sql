-- Migration: Ajout des badges genre Science-Fiction (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_sf_apprenti', 'Apprenti', 'Lire 5 livres de science-fiction', '🚀', 'genres', 5, '#1A237E', false, false, 'livres', 25),
  ('genre_sf_adepte', 'Adepte', 'Lire 15 livres de science-fiction', '🛸', 'genres', 15, '#1A237E', false, false, 'livres', 26),
  ('genre_sf_maitre', 'Maitre', 'Lire 30 livres de science-fiction', '🌌', 'genres', 30, '#1A237E', false, false, 'livres', 27),
  ('genre_sf_legende', 'Légende', 'Lire 50 livres de science-fiction', '🏆', 'genres', 50, '#1A237E', false, false, 'livres', 28)
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

-- Migration: Ajout des badges genre Romance (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_romance_apprenti', 'Apprenti', 'Lire 5 romances', '💕', 'genres', 5, '#C2185B', false, false, 'livres', 25),
  ('genre_romance_adepte', 'Adepte', 'Lire 15 romances', '💘', 'genres', 15, '#C2185B', false, false, 'livres', 26),
  ('genre_romance_maitre', 'Maitre', 'Lire 30 romances', '💖', 'genres', 30, '#C2185B', false, false, 'livres', 27),
  ('genre_romance_legende', 'Légende', 'Lire 50 romances', '🏆', 'genres', 50, '#C2185B', false, false, 'livres', 28)
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

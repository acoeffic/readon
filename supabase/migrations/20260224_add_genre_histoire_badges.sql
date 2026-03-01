-- Migration: Ajout des badges genre Histoire (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_histoire_apprenti', 'Apprenti', 'Lire 5 livres d''histoire', '🏛️', 'genres', 5, '#4E342E', false, false, 'livres', 37),
  ('genre_histoire_adepte', 'Adepte', 'Lire 15 livres d''histoire', '📜', 'genres', 15, '#4E342E', false, false, 'livres', 38),
  ('genre_histoire_maitre', 'Maitre', 'Lire 30 livres d''histoire', '⚔️', 'genres', 30, '#4E342E', false, false, 'livres', 39),
  ('genre_histoire_legende', 'Légende', 'Lire 50 livres d''histoire', '🏆', 'genres', 50, '#4E342E', false, false, 'livres', 40)
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

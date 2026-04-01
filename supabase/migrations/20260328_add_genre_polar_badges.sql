-- Migration: Ajout des badges genre Polar/Thriller (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_polar_apprenti', 'Apprenti', 'Lire 5 polars/thrillers', '🔍', 'genres', 5, '#1B5E20', false, false, 'livres', 21),
  ('genre_polar_adepte', 'Adepte', 'Lire 15 polars/thrillers', '🕵️', 'genres', 15, '#1B5E20', false, false, 'livres', 22),
  ('genre_polar_maitre', 'Maitre', 'Lire 30 polars/thrillers', '🗡️', 'genres', 30, '#1B5E20', false, false, 'livres', 23),
  ('genre_polar_legende', 'Légende', 'Lire 50 polars/thrillers', '🏆', 'genres', 50, '#1B5E20', false, false, 'livres', 24)
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

-- Migration: Ajout des badges genre Biographie (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_bio_apprenti', 'Apprenti', 'Lire 5 biographies', '📖', 'genres', 5, '#5D4037', false, false, 'livres', 33),
  ('genre_bio_adepte', 'Adepte', 'Lire 15 biographies', '📝', 'genres', 15, '#5D4037', false, false, 'livres', 34),
  ('genre_bio_maitre', 'Maitre', 'Lire 30 biographies', '✍️', 'genres', 30, '#5D4037', false, false, 'livres', 35),
  ('genre_bio_legende', 'Légende', 'Lire 50 biographies', '🏆', 'genres', 50, '#5D4037', false, false, 'livres', 36)
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

-- Migration: Ajout des badges genre Développement Personnel (4 niveaux)
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_devperso_apprenti', 'Apprenti', 'Lire 5 livres de développement personnel', '🌱', 'genres', 5, '#00695C', false, false, 'livres', 41),
  ('genre_devperso_adepte', 'Adepte', 'Lire 15 livres de développement personnel', '🧘', 'genres', 15, '#00695C', false, false, 'livres', 42),
  ('genre_devperso_maitre', 'Maitre', 'Lire 30 livres de développement personnel', '💡', 'genres', 30, '#00695C', false, false, 'livres', 43),
  ('genre_devperso_legende', 'Légende', 'Lire 50 livres de développement personnel', '🏆', 'genres', 50, '#00695C', false, false, 'livres', 44)
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

-- Migration: ajout des badges "maitre" pour les genres Thriller et Fantasy.
-- Correspondent aux visuels badge-46-maitre-du-thriller.png et
-- badge-49-maitre-de-la-fantasy.png (dossier `Image/badge/Last/`).
-- Catégorie: genres

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('genre_thriller_maitre', 'Maitre du Thriller', 'Lire 30 thrillers', '🗡️', 'genres', 30, '#B71C1C', false, false, 'livres', 47),
  ('genre_fantasy_maitre', 'Maitre de la Fantasy', 'Lire 30 livres de fantasy', '🐉', 'genres', 30, '#311B92', false, false, 'livres', 51)
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

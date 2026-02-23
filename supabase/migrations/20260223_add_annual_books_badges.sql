-- Migration: Ajout des badges "Livre annuel" (cadence de lecture annuelle)
-- Catégorie: annual_books

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, progress_unit, sort_order)
VALUES
  ('annual_1_per_month', 'Un par Mois sur un an', 'La cadence de base', '📅', 'annual_books', 12, '#7E57C2', false, 'mois', 1),
  ('annual_2_per_month', '24 livres par an', 'Deux par mois, soutenu', '📅', 'annual_books', 24, '#7E57C2', false, 'livres', 2),
  ('annual_1_per_week', '52 par an', 'Un par semaine, une machine', '📅', 'annual_books', 52, '#7E57C2', false, 'livres', 3),
  ('annual_centenaire', 'Centenaire', 'L''exploit absolu', '📅', 'annual_books', 100, '#7E57C2', false, 'livres', 4)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  category = EXCLUDED.category,
  requirement = EXCLUDED.requirement,
  color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium,
  progress_unit = EXCLUDED.progress_unit,
  sort_order = EXCLUDED.sort_order;

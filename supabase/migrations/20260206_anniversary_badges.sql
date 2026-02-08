-- ============================================================================
-- MIGRATION: Badges Anniversaire ReadOn
-- ============================================================================
-- Ajoute 5 badges anniversaire (1-5 ans) dans la catégorie 'anniversary'
-- Badges gratuits : 1, 2, 3 ans
-- Badges premium : 4, 5 ans
-- ============================================================================

-- S'assurer que les colonnes nécessaires existent
ALTER TABLE badges ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS is_secret BOOLEAN DEFAULT false;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS is_animated BOOLEAN DEFAULT false;
ALTER TABLE badges ADD COLUMN IF NOT EXISTS progress_unit TEXT DEFAULT 'livres';
ALTER TABLE badges ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, is_animated, progress_unit, sort_order)
VALUES
  (
    'anniversary_1',
    'Première Bougie 🌱',
    'Tu as planté la graine. Un an de lectures partagées, de sessions inspirantes et de découvertes.',
    '🌱',
    'anniversary',
    1,
    '#6B988D',
    false,
    false,
    true,
    'ans',
    1
  ),
  (
    'anniversary_2',
    'Lecteur Fidèle 📖',
    'Deux ans déjà ! Ta passion pour la lecture ne faiblit pas. Tu fais partie des piliers de la communauté.',
    '📖',
    'anniversary',
    2,
    '#C4956A',
    false,
    false,
    true,
    'ans',
    2
  ),
  (
    'anniversary_3',
    'Sage des Pages 🦉',
    'Trois ans de sagesse littéraire. Ton parcours inspire les nouveaux lecteurs qui rejoignent l''aventure.',
    '🦉',
    'anniversary',
    3,
    '#8B7355',
    false,
    false,
    true,
    'ans',
    3
  ),
  (
    'anniversary_4',
    'Étoile Littéraire ✨',
    'Quatre ans d''étoiles dans les yeux. Ta constance est remarquable, tu brilles dans la galaxie ReadOn.',
    '✨',
    'anniversary',
    4,
    '#7A6FA0',
    true,
    false,
    true,
    'ans',
    4
  ),
  (
    'anniversary_5',
    'Légende Vivante 👑',
    'Cinq ans. Tu es une légende. Les livres t''ont transformé et tu as transformé cette communauté.',
    '👑',
    'anniversary',
    5,
    '#C49A2A',
    true,
    false,
    true,
    'ans',
    5
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  category = EXCLUDED.category,
  requirement = EXCLUDED.requirement,
  color = EXCLUDED.color,
  is_premium = EXCLUDED.is_premium,
  is_secret = EXCLUDED.is_secret,
  is_animated = EXCLUDED.is_animated,
  progress_unit = EXCLUDED.progress_unit,
  sort_order = EXCLUDED.sort_order;

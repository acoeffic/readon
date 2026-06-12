-- Resync badges table with the source-of-truth bucket
-- (147 PNGs in storage `asset/Image/badge/badges_renamed/`)
-- - Removes 19 obsolete ids no longer present in bucket
-- - Re-inserts 28 missing ids (annual_books, occasions, 4 genre progressions)
-- - Leaves the 9 `genre_master_*` entries untouched (4 already in DB, 5 deferred)

BEGIN;

-- 1. Remove user_badges referencing obsolete ids (no FK cascade defined)
DELETE FROM user_badges WHERE badge_id IN (
  'comeback_1m','comeback_1w','comeback_2w','comeback_3m',
  'early_bird_1','early_bird_2','early_bird_3',
  'genre_fantasy_maitre','genre_thriller_maitre',
  'marathon_1','marathon_2','marathon_3','marathon_4',
  'night_owl_1','night_owl_2','night_owl_3',
  'trophy_fidelite_quotidienne','trophy_lecture_imprevue','trophy_toujours_un_livre'
);

-- 2. Remove obsolete badges
DELETE FROM badges WHERE id IN (
  'comeback_1m','comeback_1w','comeback_2w','comeback_3m',
  'early_bird_1','early_bird_2','early_bird_3',
  'genre_fantasy_maitre','genre_thriller_maitre',
  'marathon_1','marathon_2','marathon_3','marathon_4',
  'night_owl_1','night_owl_2','night_owl_3',
  'trophy_fidelite_quotidienne','trophy_lecture_imprevue','trophy_toujours_un_livre'
);

-- 3. Re-insert annual_books (4)
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

-- 4. Re-insert genre progressions: SF, Romance, Histoire, Devperso (16 = 4 × 4)
INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  -- Science-Fiction
  ('genre_sf_apprenti', 'Apprenti', 'Lire 5 livres de science-fiction', '🚀', 'genres', 5, '#1A237E', false, false, 'livres', 25),
  ('genre_sf_adepte', 'Adepte', 'Lire 15 livres de science-fiction', '🛸', 'genres', 15, '#1A237E', false, false, 'livres', 26),
  ('genre_sf_maitre', 'Maitre', 'Lire 30 livres de science-fiction', '🌌', 'genres', 30, '#1A237E', false, false, 'livres', 27),
  ('genre_sf_legende', 'Légende', 'Lire 50 livres de science-fiction', '🏆', 'genres', 50, '#1A237E', false, false, 'livres', 28),
  -- Romance
  ('genre_romance_apprenti', 'Apprenti', 'Lire 5 romances', '💕', 'genres', 5, '#C2185B', false, false, 'livres', 45),
  ('genre_romance_adepte', 'Adepte', 'Lire 15 romances', '💘', 'genres', 15, '#C2185B', false, false, 'livres', 46),
  ('genre_romance_maitre', 'Maitre', 'Lire 30 romances', '💖', 'genres', 30, '#C2185B', false, false, 'livres', 47),
  ('genre_romance_legende', 'Légende', 'Lire 50 romances', '🏆', 'genres', 50, '#C2185B', false, false, 'livres', 48),
  -- Histoire
  ('genre_histoire_apprenti', 'Apprenti', 'Lire 5 livres d''histoire', '🏛️', 'genres', 5, '#4E342E', false, false, 'livres', 37),
  ('genre_histoire_adepte', 'Adepte', 'Lire 15 livres d''histoire', '📜', 'genres', 15, '#4E342E', false, false, 'livres', 38),
  ('genre_histoire_maitre', 'Maitre', 'Lire 30 livres d''histoire', '⚔️', 'genres', 30, '#4E342E', false, false, 'livres', 39),
  ('genre_histoire_legende', 'Légende', 'Lire 50 livres d''histoire', '🏆', 'genres', 50, '#4E342E', false, false, 'livres', 40),
  -- Développement Personnel
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

-- 5. Re-insert occasions (12)
INSERT INTO badges (id, name, description, icon, category, requirement, color, is_premium, is_secret, progress_unit, sort_order)
VALUES
  ('occasion_bastille_day', 'Prise de la Bastille', 'Lire plus de 15 minutes le 14 juillet', '🇫🇷', 'occasion', 1, '#002395', false, true, '', 1),
  ('occasion_christmas', 'Lecture de Noël', 'Lire plus de 15 minutes le 25 décembre', '🎄', 'occasion', 1, '#C62828', false, true, '', 2),
  ('occasion_fete_musique', 'Lecture en musique', 'Lire plus de 15 minutes le 21 juin', '🎵', 'occasion', 1, '#FF6D00', false, true, '', 3),
  ('occasion_halloween', 'Lecture frisson', 'Lire plus de 15 minutes le 31 octobre', '🎃', 'occasion', 1, '#FF6F00', false, true, '', 4),
  ('occasion_summer_read', 'Lecture au soleil', 'Lire plus de 15 minutes le 15 août', '☀️', 'occasion', 1, '#FFA000', false, true, '', 5),
  ('occasion_valentine', 'Lecture de l''amour', 'Lire plus de 15 minutes le 14 février', '❤️', 'occasion', 1, '#E91E63', false, true, '', 6),
  ('occasion_nye', 'Lecture du Réveillon', 'Lire plus de 15 minutes le 31 décembre', '🎆', 'occasion', 1, '#FFD700', false, true, '', 7),
  ('occasion_labour_day', 'Pause méritée', 'Lire plus de 15 minutes le 1er mai', '✊', 'occasion', 1, '#D32F2F', false, true, '', 8),
  ('occasion_world_book_day', 'Journée du livre', 'Lire plus de 15 minutes le 23 avril', '📚', 'occasion', 1, '#6D4C41', false, true, '', 9),
  ('occasion_new_year', 'Premier Chapitre de l''Année', 'Lire plus de 15 minutes le 1er janvier', '🎉', 'occasion', 1, '#1565C0', false, true, '', 10),
  ('occasion_easter', 'Lecture de Pâques', 'Lire plus de 15 minutes le jour de Pâques', '🐣', 'occasion', 1, '#7B1FA2', false, true, '', 11),
  ('occasion_april_fools', 'Poisson d''Avril', 'Lire plus de 15 minutes le 1er avril', '🐟', 'occasion', 1, '#00ACC1', false, true, '', 12)
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

COMMIT;

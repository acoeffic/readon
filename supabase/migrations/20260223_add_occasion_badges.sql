-- Migration: Ajout des badges "Occasion" (dates spéciales)
-- Catégorie: occasion

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

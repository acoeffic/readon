-- Migration: Update "Premier Chapitre" badge metadata
-- Nouveau design médaillon cranté + nouvelles métadonnées

UPDATE badges
SET
  name = 'Premier Chapitre',
  description = 'Ton aventure commence ici. Tu as terminé ton tout premier livre sur ReadOn — le début d''une longue histoire.',
  icon = '📕',
  color = '#6B988D'
WHERE id = 'books_1';

-- Remove all reading_speed badges (category no longer used)
DELETE FROM user_badges WHERE badge_id IN (
  SELECT id FROM badges WHERE category = 'reading_speed'
);
DELETE FROM badges WHERE category = 'reading_speed';

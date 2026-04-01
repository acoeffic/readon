-- Remove all old premium genre master badges (replaced by the tiered system)
DELETE FROM user_badges WHERE badge_id LIKE 'genre_master_%';
DELETE FROM badges WHERE id LIKE 'genre_master_%';

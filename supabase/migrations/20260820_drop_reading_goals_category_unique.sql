-- 2026-08-20 : fix erreur 23505 sur la page "Mes objectifs"
--
-- L'index unique partiel idx_reading_goals_active_per_category
-- (user_id, category, year) WHERE is_active = TRUE existait en prod
-- (absent des migrations du repo) et n'autorisait qu'UN objectif actif
-- par catégorie. Or la page Mes objectifs permet d'en sélectionner
-- plusieurs par catégorie (plusieurs objectifs de qualité cochés,
-- ou jours/semaine + flow + minutes/jour en régularité), et
-- saveAllGoals() insère toutes les lignes en un seul batch
-- → duplicate key value violates unique constraint (23505).
--
-- L'unicité réellement voulue est déjà garantie par
-- idx_reading_goals_active_per_type (user_id, goal_type, year)
-- WHERE is_active = TRUE, qu'on conserve.
--
-- Appliqué en prod le 2026-08-20 (migration drop_reading_goals_category_unique).

DROP INDEX IF EXISTS idx_reading_goals_active_per_category;

-- Défis des clubs publics visibles par les non-membres (anon + authenticated).
--
-- Jusqu'ici la seule policy SELECT sur group_challenges était
-- « Members can view group challenges » (is_group_member) : un visiteur
-- d'un club public voyait ses membres et son fil d'activité (ouverts par
-- 20260516_guest_mode_public_access) mais « Aucun défi actif », alors que
-- le défi est l'argument le plus concret pour rejoindre. Constaté le
-- 14/09/2026 sur Club Philosophie (défi « Manuel, Épictète » invisible
-- avec le bouton « Demander à rejoindre »).
--
-- Policies additives (OR) : rien ne change pour les membres ni pour les
-- clubs privés ; INSERT/UPDATE/DELETE restent réservés admins/participants.

DROP POLICY IF EXISTS "Anyone can view challenges of public groups" ON group_challenges;
CREATE POLICY "Anyone can view challenges of public groups"
  ON group_challenges FOR SELECT
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM reading_groups rg
    WHERE rg.id = group_challenges.group_id AND rg.is_private = false
  ));

DROP POLICY IF EXISTS "Anyone can view participants of public group challenges" ON challenge_participants;
CREATE POLICY "Anyone can view participants of public group challenges"
  ON challenge_participants FOR SELECT
  TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM group_challenges gc
    JOIN reading_groups rg ON rg.id = gc.group_id
    WHERE gc.id = challenge_participants.challenge_id AND rg.is_private = false
  ));

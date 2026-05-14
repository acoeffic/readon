-- ============================================================================
-- MIGRATION: Mode invité — accès public en lecture seule
-- ============================================================================
-- Apple App Store guideline 5.1.1 : permettre l'accès au contenu non-personnel
-- sans création de compte. On ajoute des policies SELECT pour le rôle `anon`
-- (utilisateur Supabase non-authentifié) qui autorisent uniquement la lecture
-- du contenu marqué public.
--
-- Stratégie : on AJOUTE des policies sans toucher l'existant. Les policies
-- multiples sur même table+commande+rôle sont combinées en OR — donc cet ajout
-- ne fait qu'élargir l'accès, sans casser l'auth existante.
-- ============================================================================

-- ============================================================================
-- 1. PROFILES — lecture des profils publics par les invités
-- ============================================================================
-- Champ `is_profile_private` (BOOLEAN) déjà présent. NULL = public par défaut.

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anon can view public profiles" ON profiles;
CREATE POLICY "Anon can view public profiles"
  ON profiles FOR SELECT
  TO anon
  USING (COALESCE(is_profile_private, FALSE) = FALSE);

-- ============================================================================
-- 2. READING_GROUPS — lecture des clubs publics par les invités
-- ============================================================================
-- Champ `is_private` (BOOLEAN DEFAULT false).
-- La policy existante n'a pas de TO restrictif mais on garantit l'accès anon.

DROP POLICY IF EXISTS "Anon can view public groups" ON reading_groups;
CREATE POLICY "Anon can view public groups"
  ON reading_groups FOR SELECT
  TO anon
  USING (is_private = false);

-- ============================================================================
-- 3. GROUP_MEMBERS — lecture des membres des clubs publics
-- ============================================================================

DROP POLICY IF EXISTS "Anon can view members of public groups" ON group_members;
CREATE POLICY "Anon can view members of public groups"
  ON group_members FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM reading_groups
      WHERE reading_groups.id = group_members.group_id
        AND reading_groups.is_private = false
    )
  );

-- ============================================================================
-- 4. GROUP_ACTIVITIES — lecture des discussions des clubs publics
-- ============================================================================

DROP POLICY IF EXISTS "Anon can view activities of public groups" ON group_activities;
CREATE POLICY "Anon can view activities of public groups"
  ON group_activities FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM reading_groups
      WHERE reading_groups.id = group_activities.group_id
        AND reading_groups.is_private = false
    )
  );

-- ============================================================================
-- 5. BOOKS — lecture publique du catalogue (déjà autorisée pour authenticated)
-- ============================================================================
-- Permet aux invités de voir les fiches livres lorsqu'ils explorent un club
-- public ou un profil public.

DROP POLICY IF EXISTS "Anon can view books" ON books;
CREATE POLICY "Anon can view books"
  ON books FOR SELECT
  TO anon
  USING (true);

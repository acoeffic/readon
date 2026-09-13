-- ============================================================================
-- MIGRATION: Partage des listes perso (2026-08-31)
-- ============================================================================
-- Une liste marquée is_public devient consultable :
--   - sur le web via https://www.lexday.fr/liste/{share_token} (rôle anon)
--   - dans l'app par les autres utilisateurs via lexday://list/{id}
-- Le share_token (uuid aléatoire) évite des URLs énumérables par id.
-- ============================================================================

ALTER TABLE user_custom_lists
  ADD COLUMN IF NOT EXISTS share_token uuid NOT NULL DEFAULT gen_random_uuid();

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_custom_lists_share_token
  ON user_custom_lists (share_token);

-- Lecture anon des listes publiques (page web). Les policies multiples sur
-- même table+commande+rôle sont combinées en OR : on élargit sans rien casser.
DROP POLICY IF EXISTS "Anon can view public custom lists" ON user_custom_lists;
CREATE POLICY "Anon can view public custom lists"
ON user_custom_lists FOR SELECT TO anon
USING (is_public = true);

-- Items des listes publiques : lisibles par anon (web) ET par les autres
-- utilisateurs connectés (deep link in-app). La policy existante ne couvrait
-- que le propriétaire.
DROP POLICY IF EXISTS "Anyone can view books in public lists" ON user_custom_list_books;
CREATE POLICY "Anyone can view books in public lists"
ON user_custom_list_books FOR SELECT TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_custom_lists
    WHERE user_custom_lists.id = user_custom_list_books.list_id
      AND user_custom_lists.is_public = true
  )
);

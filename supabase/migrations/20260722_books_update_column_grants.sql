-- Fix advisor rls_policy_always_true sur books (UPDATE) + hygiène RLS
-- L'enrichissement communautaire du catalogue (couvertures, descriptions…)
-- est voulu côté client, mais il ne touche que 7 colonnes de métadonnées.
-- Le garde-fou devient un grant par colonne : title & co ne sont plus
-- modifiables par les clients.
-- Appliquée en prod le 22/07/2026 (migration `books_update_column_grants`).

-- 1. UPDATE limité aux colonnes d'enrichissement
REVOKE UPDATE ON public.books FROM anon, authenticated;
GRANT UPDATE (author, genre, description, cover_url, page_count, google_id, isbn)
  ON public.books TO authenticated;

-- 2. Policy équivalente mais explicite (remplace USING (true))
DROP POLICY IF EXISTS "Users can update books" ON public.books;
CREATE POLICY "Authenticated users can enrich book metadata"
  ON public.books FOR UPDATE TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- 3. audit_log / speed_violations : backend-only voulu (RLS deny-all,
--    écrites via fonctions SECURITY DEFINER). Défense en profondeur :
--    retirer aussi les privilèges table aux rôles client.
REVOKE ALL ON public.audit_log FROM anon, authenticated;
REVOKE ALL ON public.speed_violations FROM anon, authenticated;

-- Appliquée en prod le 22/07/2026 (migration `mv_api_and_storage_listing_lockdown`).

-- 1. Vues matérialisées hors de l'API REST (advisor materialized_view_in_api)
--    Lecture uniquement via les RPC SECURITY DEFINER (get_trending_books_by_sessions,
--    get_community_sessions) — l'app ne les requête jamais en direct.
REVOKE ALL ON public.mv_trending_books FROM anon, authenticated;
REVOKE ALL ON public.mv_community_sessions FROM anon, authenticated;

-- 2. Buckets publics : suppression du listing via l'API
--    (advisor public_bucket_allows_listing). Les objets restent servis via
--    les URLs publiques /object/public/… qui ne passent pas par la RLS.
--    L'app n'utilise que getPublicUrl (aucun .list()/.download()).
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Group images are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Public read access on badge-cards" ON storage.objects;
DROP POLICY IF EXISTS "Public read access on shares" ON storage.objects;

-- 3. badge-cards : INSERT/UPDATE étaient nommés "Service role …" mais
--    appliqués à roles={public} → upload/écrasement possible avec la clé
--    anon. Re-scope sur service_role (qui bypass la RLS de toute façon,
--    comme pour le bucket shares).
DROP POLICY IF EXISTS "Service role upload on badge-cards" ON storage.objects;
DROP POLICY IF EXISTS "Service role update on badge-cards" ON storage.objects;
CREATE POLICY "Service role upload on badge-cards" ON storage.objects
  FOR INSERT TO service_role WITH CHECK (bucket_id = 'badge-cards');
CREATE POLICY "Service role update on badge-cards" ON storage.objects
  FOR UPDATE TO service_role USING (bucket_id = 'badge-cards');

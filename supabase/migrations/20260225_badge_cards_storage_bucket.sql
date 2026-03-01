-- Migration: Configuration du bucket storage "badge-cards" pour les cartes de badges partagées
-- Les cartes PNG sont générées par la Edge Function generate-badge-card et stockées ici

-- 1. Créer le bucket public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'badge-cards',
  'badge-cards',
  true,
  2097152,  -- 2MB max
  ARRAY['image/png']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 2097152,
  allowed_mime_types = ARRAY['image/png'];

-- 2. Politique de lecture publique (tout le monde peut voir les cartes)
DROP POLICY IF EXISTS "Public read access on badge-cards" ON storage.objects;
CREATE POLICY "Public read access on badge-cards"
ON storage.objects FOR SELECT
USING (bucket_id = 'badge-cards');

-- 3. Politique d'upload pour service_role uniquement (Edge Function)
DROP POLICY IF EXISTS "Service role upload on badge-cards" ON storage.objects;
CREATE POLICY "Service role upload on badge-cards"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'badge-cards');

-- 4. Politique de mise à jour pour service_role (upsert)
DROP POLICY IF EXISTS "Service role update on badge-cards" ON storage.objects;
CREATE POLICY "Service role update on badge-cards"
ON storage.objects FOR UPDATE
USING (bucket_id = 'badge-cards');

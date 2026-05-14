-- Migration: Configuration du bucket storage "groups" pour les images de clubs de lecture

-- 1. Créer le bucket public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'groups',
  'groups',
  true,
  5242880,  -- 5MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- 2. Lecture publique (tout le monde peut voir les images de groupes)
DROP POLICY IF EXISTS "Group images are publicly accessible" ON storage.objects;
CREATE POLICY "Group images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'groups');

-- 3. Upload (utilisateurs authentifiés)
DROP POLICY IF EXISTS "Authenticated users can upload group images" ON storage.objects;
CREATE POLICY "Authenticated users can upload group images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'groups'
  AND auth.role() = 'authenticated'
);

-- 4. Mise à jour
DROP POLICY IF EXISTS "Authenticated users can update group images" ON storage.objects;
CREATE POLICY "Authenticated users can update group images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'groups'
  AND auth.role() = 'authenticated'
);

-- 5. Suppression
DROP POLICY IF EXISTS "Authenticated users can delete group images" ON storage.objects;
CREATE POLICY "Authenticated users can delete group images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'groups'
  AND auth.role() = 'authenticated'
);

-- Migration: Annotations privées uniquement
-- Les annotations ne doivent être accessibles qu'à l'utilisateur qui les a créées

-- ============================================================================
-- 1. Supprimer la policy de visibilité amis
-- ============================================================================

DROP POLICY IF EXISTS "Users can view public annotations from friends" ON annotations;

-- ============================================================================
-- 2. Supprimer la colonne is_public (plus nécessaire)
-- ============================================================================

ALTER TABLE annotations DROP COLUMN IF EXISTS is_public;

-- ============================================================================
-- 3. Restreindre le storage aux seuls propriétaires
-- ============================================================================

-- Remplacer la lecture publique par une lecture restreinte au propriétaire
DROP POLICY IF EXISTS "Annotation images are publicly accessible" ON storage.objects;
CREATE POLICY "Users can view own annotation files"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'annotations'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

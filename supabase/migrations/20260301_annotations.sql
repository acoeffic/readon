-- Migration: Table annotations + Storage bucket pour les annotations de lecture
-- Permet aux utilisateurs de capturer des pensées, citations et photos pendant leurs sessions

-- ============================================================================
-- 1. Table annotations
-- ============================================================================

CREATE TABLE IF NOT EXISTS annotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  book_id TEXT NOT NULL,
  session_id UUID REFERENCES reading_sessions(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  page_number INTEGER,
  type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'photo', 'voice')),
  image_path TEXT,
  ai_summary TEXT,
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 2. Indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_annotations_user_book ON annotations (user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_annotations_session ON annotations (session_id);
CREATE INDEX IF NOT EXISTS idx_annotations_created_at ON annotations (created_at);

-- ============================================================================
-- 3. Trigger updated_at automatique
-- ============================================================================

CREATE OR REPLACE FUNCTION update_annotations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_annotations_updated_at ON annotations;
CREATE TRIGGER trigger_annotations_updated_at
  BEFORE UPDATE ON annotations
  FOR EACH ROW
  EXECUTE FUNCTION update_annotations_updated_at();

-- ============================================================================
-- 4. RLS Policies
-- ============================================================================

ALTER TABLE annotations ENABLE ROW LEVEL SECURITY;

-- SELECT : ses propres annotations + annotations publiques de ses amis
DROP POLICY IF EXISTS "Users can view own annotations" ON annotations;
CREATE POLICY "Users can view own annotations"
ON annotations FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can view public annotations from friends" ON annotations;
CREATE POLICY "Users can view public annotations from friends"
ON annotations FOR SELECT
USING (
  is_public = true
  AND user_id IN (
    SELECT addressee_id FROM friends
    WHERE requester_id = auth.uid() AND status = 'accepted'
    UNION
    SELECT requester_id FROM friends
    WHERE addressee_id = auth.uid() AND status = 'accepted'
  )
);

-- INSERT : uniquement ses propres annotations
DROP POLICY IF EXISTS "Users can insert own annotations" ON annotations;
CREATE POLICY "Users can insert own annotations"
ON annotations FOR INSERT
WITH CHECK (user_id = auth.uid());

-- UPDATE : uniquement ses propres annotations
DROP POLICY IF EXISTS "Users can update own annotations" ON annotations;
CREATE POLICY "Users can update own annotations"
ON annotations FOR UPDATE
USING (user_id = auth.uid());

-- DELETE : uniquement ses propres annotations
DROP POLICY IF EXISTS "Users can delete own annotations" ON annotations;
CREATE POLICY "Users can delete own annotations"
ON annotations FOR DELETE
USING (user_id = auth.uid());

-- ============================================================================
-- 5. Storage bucket pour les images d'annotations
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'annotations',
  'annotations',
  true,
  5242880,  -- 5MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- Lecture publique des images d'annotations
DROP POLICY IF EXISTS "Annotation images are publicly accessible" ON storage.objects;
CREATE POLICY "Annotation images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'annotations');

-- Upload : utilisateurs authentifiés dans leur propre dossier
DROP POLICY IF EXISTS "Users can upload annotation images" ON storage.objects;
CREATE POLICY "Users can upload annotation images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'annotations'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Update : utilisateurs dans leur propre dossier
DROP POLICY IF EXISTS "Users can update annotation images" ON storage.objects;
CREATE POLICY "Users can update annotation images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'annotations'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Delete : utilisateurs dans leur propre dossier
DROP POLICY IF EXISTS "Users can delete annotation images" ON storage.objects;
CREATE POLICY "Users can delete annotation images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'annotations'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

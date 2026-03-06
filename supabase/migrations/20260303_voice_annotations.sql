-- Migration: Ajouter audio_path sur annotations + MIME types audio dans le bucket
-- Support des annotations vocales (enregistrement + transcription Whisper)

ALTER TABLE annotations ADD COLUMN IF NOT EXISTS audio_path TEXT;

UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg', 'image/png', 'image/webp', 'image/jpg',
  'audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/aac'
]
WHERE id = 'annotations';

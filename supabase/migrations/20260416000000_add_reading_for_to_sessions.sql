-- Add "reading_for" column to track who the user is reading to/for
ALTER TABLE reading_sessions
  ADD COLUMN IF NOT EXISTS reading_for text;

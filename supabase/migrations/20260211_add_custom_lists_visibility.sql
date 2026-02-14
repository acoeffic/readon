-- Migration: Add public/private visibility to custom lists
-- Allows users to choose if their custom list is visible to others

ALTER TABLE user_custom_lists
  ADD COLUMN is_public boolean NOT NULL DEFAULT false;

-- Allow authenticated users to see public lists from other users
CREATE POLICY "Users can view public custom lists"
ON user_custom_lists FOR SELECT TO authenticated
USING (is_public = true);

-- =====================================================
-- Migration: Group reading challenges
-- =====================================================

-- =====================================================
-- 1. GROUP_CHALLENGES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS group_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES reading_groups(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  target_book_id BIGINT REFERENCES books(id) ON DELETE SET NULL,
  target_value INT NOT NULL DEFAULT 0,
  target_days INT,
  starts_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT valid_challenge_type CHECK (type IN ('read_book', 'read_pages', 'read_daily')),
  CONSTRAINT title_not_empty CHECK (char_length(title) > 0),
  CONSTRAINT title_max_length CHECK (char_length(title) <= 150),
  CONSTRAINT positive_target CHECK (target_value > 0),
  CONSTRAINT ends_after_starts CHECK (ends_at > starts_at)
);

CREATE INDEX idx_group_challenges_group ON group_challenges(group_id);
CREATE INDEX idx_group_challenges_ends_at ON group_challenges(ends_at);

-- =====================================================
-- 2. CHALLENGE_PARTICIPANTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS challenge_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES group_challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  progress INT NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE,

  UNIQUE(challenge_id, user_id)
);

CREATE INDEX idx_challenge_participants_challenge ON challenge_participants(challenge_id);
CREATE INDEX idx_challenge_participants_user ON challenge_participants(user_id);

-- =====================================================
-- 3. RLS POLICIES - GROUP_CHALLENGES
-- =====================================================
ALTER TABLE group_challenges ENABLE ROW LEVEL SECURITY;

-- Members can view challenges in their groups
CREATE POLICY "Members can view group challenges"
  ON group_challenges FOR SELECT
  USING (
    is_group_member(group_id, auth.uid())
  );

-- Only admins can create challenges
CREATE POLICY "Admins can create challenges"
  ON group_challenges FOR INSERT
  WITH CHECK (
    is_group_admin(group_id, auth.uid())
    AND creator_id = auth.uid()
  );

-- Only admins can delete challenges
CREATE POLICY "Admins can delete challenges"
  ON group_challenges FOR DELETE
  USING (
    is_group_admin(group_id, auth.uid())
  );

-- =====================================================
-- 4. RLS POLICIES - CHALLENGE_PARTICIPANTS
-- =====================================================
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;

-- Members can view participants of challenges in their groups
CREATE POLICY "Members can view challenge participants"
  ON challenge_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_challenges gc
      WHERE gc.id = challenge_participants.challenge_id
      AND is_group_member(gc.group_id, auth.uid())
    )
  );

-- Members can join challenges in their groups
CREATE POLICY "Members can join challenges"
  ON challenge_participants FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_challenges gc
      WHERE gc.id = challenge_participants.challenge_id
      AND is_group_member(gc.group_id, auth.uid())
    )
  );

-- Participants can update their own progress
CREATE POLICY "Participants can update own progress"
  ON challenge_participants FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Participants can leave challenges
CREATE POLICY "Participants can leave challenges"
  ON challenge_participants FOR DELETE
  USING (user_id = auth.uid());

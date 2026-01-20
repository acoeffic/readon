-- Migration: Create reading groups tables
-- Description: Tables for managing reading groups with public/private visibility

-- =====================================================
-- 1. READING_GROUPS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS reading_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  cover_url TEXT,
  is_private BOOLEAN DEFAULT false,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT name_not_empty CHECK (char_length(name) > 0),
  CONSTRAINT name_max_length CHECK (char_length(name) <= 100),
  CONSTRAINT description_max_length CHECK (char_length(description) <= 500)
);

-- Index for faster queries
CREATE INDEX idx_reading_groups_creator ON reading_groups(creator_id);
CREATE INDEX idx_reading_groups_is_private ON reading_groups(is_private);
CREATE INDEX idx_reading_groups_created_at ON reading_groups(created_at DESC);

-- =====================================================
-- 2. GROUP_MEMBERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES reading_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- 'admin' or 'member'
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  UNIQUE(group_id, user_id),
  CONSTRAINT valid_role CHECK (role IN ('admin', 'member'))
);

-- Indexes
CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);

-- =====================================================
-- 3. GROUP_INVITATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS group_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES reading_groups(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  UNIQUE(group_id, invitee_id),
  CONSTRAINT valid_invitation_status CHECK (status IN ('pending', 'accepted', 'rejected'))
);

-- Indexes
CREATE INDEX idx_group_invitations_group ON group_invitations(group_id);
CREATE INDEX idx_group_invitations_invitee ON group_invitations(invitee_id);
CREATE INDEX idx_group_invitations_status ON group_invitations(status);

-- =====================================================
-- 4. GROUP_ACTIVITIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS group_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES reading_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL, -- 'reading_session', 'book_finished', 'joined', 'comment'
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT valid_activity_type CHECK (activity_type IN ('reading_session', 'book_finished', 'joined', 'comment', 'book_recommendation'))
);

-- Indexes
CREATE INDEX idx_group_activities_group ON group_activities(group_id);
CREATE INDEX idx_group_activities_user ON group_activities(user_id);
CREATE INDEX idx_group_activities_created_at ON group_activities(created_at DESC);

-- =====================================================
-- 5. RLS POLICIES - READING_GROUPS
-- =====================================================

-- Enable RLS
ALTER TABLE reading_groups ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone authenticated can view public groups
CREATE POLICY "Public groups are viewable by everyone"
  ON reading_groups FOR SELECT
  USING (
    is_private = false
    OR creator_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = reading_groups.id
      AND group_members.user_id = auth.uid()
    )
  );

-- Policy: Authenticated users can create groups
CREATE POLICY "Users can create groups"
  ON reading_groups FOR INSERT
  WITH CHECK (auth.uid() = creator_id);

-- Policy: Only creator can update group
CREATE POLICY "Creators can update their groups"
  ON reading_groups FOR UPDATE
  USING (auth.uid() = creator_id)
  WITH CHECK (auth.uid() = creator_id);

-- Policy: Only creator can delete group
CREATE POLICY "Creators can delete their groups"
  ON reading_groups FOR DELETE
  USING (auth.uid() = creator_id);

-- =====================================================
-- 6. RLS POLICIES - GROUP_MEMBERS
-- =====================================================

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Policy: View members if you're a member or group is public
CREATE POLICY "View group members if member or public"
  ON group_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM reading_groups
      WHERE reading_groups.id = group_members.group_id
      AND (
        reading_groups.is_private = false
        OR reading_groups.creator_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM group_members gm
          WHERE gm.group_id = group_members.group_id
          AND gm.user_id = auth.uid()
        )
      )
    )
  );

-- Policy: Admins can add members
CREATE POLICY "Admins can add members"
  ON group_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = group_members.group_id
      AND user_id = auth.uid()
      AND role = 'admin'
    )
    OR EXISTS (
      SELECT 1 FROM reading_groups
      WHERE id = group_members.group_id
      AND creator_id = auth.uid()
    )
  );

-- Policy: Admins can update member roles
CREATE POLICY "Admins can update member roles"
  ON group_members FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

-- Policy: Members can leave group (delete themselves)
CREATE POLICY "Members can leave groups"
  ON group_members FOR DELETE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

-- =====================================================
-- 7. RLS POLICIES - GROUP_INVITATIONS
-- =====================================================

ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;

-- Policy: View invitations if you're inviter or invitee
CREATE POLICY "View invitations if involved"
  ON group_invitations FOR SELECT
  USING (
    inviter_id = auth.uid()
    OR invitee_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = group_invitations.group_id
      AND group_members.user_id = auth.uid()
      AND group_members.role = 'admin'
    )
  );

-- Policy: Admins and members can invite
CREATE POLICY "Members can invite users"
  ON group_invitations FOR INSERT
  WITH CHECK (
    inviter_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = group_invitations.group_id
      AND user_id = auth.uid()
    )
  );

-- Policy: Invitee can update their invitation (accept/reject)
CREATE POLICY "Invitees can respond to invitations"
  ON group_invitations FOR UPDATE
  USING (invitee_id = auth.uid())
  WITH CHECK (invitee_id = auth.uid());

-- =====================================================
-- 8. RLS POLICIES - GROUP_ACTIVITIES
-- =====================================================

ALTER TABLE group_activities ENABLE ROW LEVEL SECURITY;

-- Policy: View activities if member of group
CREATE POLICY "View group activities if member"
  ON group_activities FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = group_activities.group_id
      AND group_members.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM reading_groups
      WHERE reading_groups.id = group_activities.group_id
      AND reading_groups.is_private = false
    )
  );

-- Policy: Members can create activities
CREATE POLICY "Members can create activities"
  ON group_activities FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = group_activities.group_id
      AND user_id = auth.uid()
    )
  );

-- =====================================================
-- 9. FUNCTIONS - Get User Groups
-- =====================================================

CREATE OR REPLACE FUNCTION get_user_groups(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  cover_url TEXT,
  is_private BOOLEAN,
  creator_id UUID,
  created_at TIMESTAMP WITH TIME ZONE,
  member_count BIGINT,
  user_role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rg.id,
    rg.name,
    rg.description,
    rg.cover_url,
    rg.is_private,
    rg.creator_id,
    rg.created_at,
    COUNT(gm.id) AS member_count,
    user_gm.role AS user_role
  FROM reading_groups rg
  INNER JOIN group_members user_gm ON rg.id = user_gm.group_id AND user_gm.user_id = p_user_id
  LEFT JOIN group_members gm ON rg.id = gm.group_id
  GROUP BY rg.id, rg.name, rg.description, rg.cover_url, rg.is_private, rg.creator_id, rg.created_at, user_gm.role
  ORDER BY rg.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 10. FUNCTIONS - Get Public Groups
-- =====================================================

CREATE OR REPLACE FUNCTION get_public_groups(p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  cover_url TEXT,
  creator_id UUID,
  creator_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  member_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rg.id,
    rg.name,
    rg.description,
    rg.cover_url,
    rg.creator_id,
    p.display_name AS creator_name,
    rg.created_at,
    COUNT(gm.id) AS member_count
  FROM reading_groups rg
  LEFT JOIN group_members gm ON rg.id = gm.group_id
  LEFT JOIN profiles p ON rg.creator_id = p.id
  WHERE rg.is_private = false
  GROUP BY rg.id, rg.name, rg.description, rg.cover_url, rg.creator_id, p.display_name, rg.created_at
  ORDER BY rg.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 11. FUNCTIONS - Get Group Invitations
-- =====================================================

CREATE OR REPLACE FUNCTION get_group_invitations(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  group_id UUID,
  group_name TEXT,
  inviter_id UUID,
  inviter_name TEXT,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    gi.id,
    gi.group_id,
    rg.name AS group_name,
    gi.inviter_id,
    p.display_name AS inviter_name,
    gi.status,
    gi.created_at
  FROM group_invitations gi
  INNER JOIN reading_groups rg ON gi.group_id = rg.id
  LEFT JOIN profiles p ON gi.inviter_id = p.id
  WHERE gi.invitee_id = p_user_id
  AND gi.status = 'pending'
  ORDER BY gi.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 12. FUNCTIONS - Respond to Group Invitation
-- =====================================================

CREATE OR REPLACE FUNCTION respond_to_group_invitation(
  p_invitation_id UUID,
  p_accept BOOLEAN
)
RETURNS BOOLEAN AS $$
DECLARE
  v_group_id UUID;
  v_invitee_id UUID;
  v_new_status TEXT;
BEGIN
  -- Get invitation details
  SELECT group_id, invitee_id INTO v_group_id, v_invitee_id
  FROM group_invitations
  WHERE id = p_invitation_id AND invitee_id = auth.uid();

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invitation not found or unauthorized';
  END IF;

  v_new_status := CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END;

  -- Update invitation status
  UPDATE group_invitations
  SET status = v_new_status, updated_at = now()
  WHERE id = p_invitation_id;

  -- If accepted, add user to group
  IF p_accept THEN
    INSERT INTO group_members (group_id, user_id, role)
    VALUES (v_group_id, v_invitee_id, 'member')
    ON CONFLICT (group_id, user_id) DO NOTHING;

    -- Create join activity
    INSERT INTO group_activities (group_id, user_id, activity_type, payload)
    VALUES (v_group_id, v_invitee_id, 'joined', jsonb_build_object('action', 'joined'));
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 13. TRIGGERS - Auto-update timestamps
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_reading_groups_updated_at
  BEFORE UPDATE ON reading_groups
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_invitations_updated_at
  BEFORE UPDATE ON group_invitations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 14. TRIGGER - Auto-add creator as admin
-- =====================================================

CREATE OR REPLACE FUNCTION add_creator_as_admin()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO group_members (group_id, user_id, role)
  VALUES (NEW.id, NEW.creator_id, 'admin');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_add_creator_as_admin
  AFTER INSERT ON reading_groups
  FOR EACH ROW
  EXECUTE FUNCTION add_creator_as_admin();

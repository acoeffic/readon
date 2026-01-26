-- =====================================================
-- FIX: Infinite recursion in group_members RLS policies
--
-- Problem: Policies on group_members reference group_members
-- in subqueries, which triggers the SELECT policy again,
-- causing infinite recursion.
--
-- Solution: Use SECURITY DEFINER functions to check
-- membership/admin status without going through RLS.
-- =====================================================

-- 1. Create helper functions (SECURITY DEFINER bypasses RLS)

CREATE OR REPLACE FUNCTION is_group_member(p_group_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id
    AND user_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_group_admin(p_group_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id
    AND user_id = p_user_id
    AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix the trigger function to use SECURITY DEFINER

CREATE OR REPLACE FUNCTION add_creator_as_admin()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO group_members (group_id, user_id, role)
  VALUES (NEW.id, NEW.creator_id, 'admin');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Drop old policies on group_members

DROP POLICY IF EXISTS "View group members if member or public" ON group_members;
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
DROP POLICY IF EXISTS "Admins can update member roles" ON group_members;
DROP POLICY IF EXISTS "Members can leave groups" ON group_members;

-- 4. Recreate policies using helper functions (no recursion)

-- SELECT: View members if group is public, you're the creator, or you're a member
CREATE POLICY "View group members if member or public"
  ON group_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM reading_groups
      WHERE reading_groups.id = group_members.group_id
      AND (
        reading_groups.is_private = false
        OR reading_groups.creator_id = auth.uid()
      )
    )
    OR is_group_member(group_id, auth.uid())
  );

-- INSERT: Admins or group creator can add members
CREATE POLICY "Admins can add members"
  ON group_members FOR INSERT
  WITH CHECK (
    is_group_admin(group_id, auth.uid())
    OR EXISTS (
      SELECT 1 FROM reading_groups
      WHERE id = group_members.group_id
      AND creator_id = auth.uid()
    )
  );

-- UPDATE: Only admins can update roles
CREATE POLICY "Admins can update member roles"
  ON group_members FOR UPDATE
  USING (
    is_group_admin(group_id, auth.uid())
  );

-- DELETE: Members can leave, admins can remove others
CREATE POLICY "Members can leave groups"
  ON group_members FOR DELETE
  USING (
    user_id = auth.uid()
    OR is_group_admin(group_id, auth.uid())
  );

-- 5. Fix reading_groups SELECT policy (also references group_members)

DROP POLICY IF EXISTS "Public groups are viewable by everyone" ON reading_groups;

CREATE POLICY "Public groups are viewable by everyone"
  ON reading_groups FOR SELECT
  USING (
    is_private = false
    OR creator_id = auth.uid()
    OR is_group_member(id, auth.uid())
  );

-- 6. Fix group_invitations policies that reference group_members

DROP POLICY IF EXISTS "View invitations if involved" ON group_invitations;
DROP POLICY IF EXISTS "Members can invite users" ON group_invitations;

CREATE POLICY "View invitations if involved"
  ON group_invitations FOR SELECT
  USING (
    inviter_id = auth.uid()
    OR invitee_id = auth.uid()
    OR is_group_admin(group_id, auth.uid())
  );

CREATE POLICY "Members can invite users"
  ON group_invitations FOR INSERT
  WITH CHECK (
    inviter_id = auth.uid()
    AND is_group_member(group_id, auth.uid())
  );

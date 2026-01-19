-- Migration pour corriger les policies RLS de la table reading_sessions

-- 1. Activer RLS sur la table reading_sessions si ce n'est pas déjà fait
ALTER TABLE reading_sessions ENABLE ROW LEVEL SECURITY;

-- 2. Supprimer les anciennes policies si elles existent
DROP POLICY IF EXISTS "Users can view their own sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can view friends sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can insert their own sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can update their own sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can delete their own sessions" ON reading_sessions;

-- 3. Créer les nouvelles policies

-- Policy pour SELECT : Les utilisateurs voient leurs propres sessions
-- ET celles de leurs amis (pour le feed)
CREATE POLICY "Users can view their own sessions"
ON reading_sessions
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR
  -- Ou si l'utilisateur est ami avec le propriétaire de la session
  EXISTS (
    SELECT 1 FROM friends
    WHERE (requester_id = auth.uid() AND addressee_id = reading_sessions.user_id AND status = 'accepted')
    OR (addressee_id = auth.uid() AND requester_id = reading_sessions.user_id AND status = 'accepted')
  )
);

-- Policy pour INSERT : Les utilisateurs peuvent créer leurs propres sessions
CREATE POLICY "Users can insert their own sessions"
ON reading_sessions
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy pour UPDATE : Les utilisateurs peuvent mettre à jour leurs propres sessions
CREATE POLICY "Users can update their own sessions"
ON reading_sessions
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy pour DELETE : Les utilisateurs peuvent supprimer leurs propres sessions
CREATE POLICY "Users can delete their own sessions"
ON reading_sessions
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================================================
-- MIGRATION COMPLÈTE : Configuration RLS pour ReadOn
-- ============================================================================
-- Cette migration configure toutes les Row Level Security policies nécessaires
-- pour le bon fonctionnement de l'application ReadOn
--
-- À exécuter dans l'éditeur SQL de Supabase
-- ============================================================================

-- ============================================================================
-- 1. TABLE BOOKS
-- ============================================================================

-- Activer RLS
ALTER TABLE books ENABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes policies
DROP POLICY IF EXISTS "Users can view all books" ON books;
DROP POLICY IF EXISTS "Users can insert books" ON books;
DROP POLICY IF EXISTS "Users can update books" ON books;

-- Créer les nouvelles policies
CREATE POLICY "Users can view all books"
ON books FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert books"
ON books FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Users can update books"
ON books FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- 2. TABLE USER_BOOKS
-- ============================================================================

-- Activer RLS
ALTER TABLE user_books ENABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes policies
DROP POLICY IF EXISTS "Users can view their own books" ON user_books;
DROP POLICY IF EXISTS "Users can insert their own books" ON user_books;
DROP POLICY IF EXISTS "Users can update their own books" ON user_books;
DROP POLICY IF EXISTS "Users can delete their own books" ON user_books;

-- Créer les nouvelles policies
CREATE POLICY "Users can view their own books"
ON user_books FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own books"
ON user_books FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own books"
ON user_books FOR UPDATE TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own books"
ON user_books FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- ============================================================================
-- 3. TABLE READING_SESSIONS
-- ============================================================================

-- Activer RLS
ALTER TABLE reading_sessions ENABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes policies
DROP POLICY IF EXISTS "Users can view their own sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can insert their own sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can update their own sessions" ON reading_sessions;
DROP POLICY IF EXISTS "Users can delete their own sessions" ON reading_sessions;

-- Créer les nouvelles policies
CREATE POLICY "Users can view their own sessions"
ON reading_sessions FOR SELECT TO authenticated
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM friends
    WHERE (requester_id = auth.uid() AND addressee_id = reading_sessions.user_id AND status = 'accepted')
    OR (addressee_id = auth.uid() AND requester_id = reading_sessions.user_id AND status = 'accepted')
  )
);

CREATE POLICY "Users can insert their own sessions"
ON reading_sessions FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sessions"
ON reading_sessions FOR UPDATE TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sessions"
ON reading_sessions FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- ============================================================================
-- VÉRIFICATION
-- ============================================================================

-- Afficher toutes les policies créées
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename IN ('books', 'user_books', 'reading_sessions')
ORDER BY tablename, policyname;

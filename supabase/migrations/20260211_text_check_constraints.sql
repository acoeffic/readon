-- Migration : Contraintes CHECK sur les champs texte
-- Empêche les valeurs vides, les chaînes trop longues,
-- et les formats invalides sur les tables principales.

-- ============================================================================
-- 1. PROFILES
-- ============================================================================
ALTER TABLE profiles
  ADD CONSTRAINT chk_profiles_display_name
    CHECK (display_name IS NULL OR (char_length(trim(display_name)) BETWEEN 1 AND 50)),
  ADD CONSTRAINT chk_profiles_email
    CHECK (email IS NULL OR (char_length(email) BETWEEN 3 AND 320)),
  ADD CONSTRAINT chk_profiles_avatar_url
    CHECK (avatar_url IS NULL OR char_length(avatar_url) <= 2048);

-- ============================================================================
-- 2. BOOKS (catalogue partagé)
-- ============================================================================
ALTER TABLE books
  ADD CONSTRAINT chk_books_title
    CHECK (char_length(trim(title)) BETWEEN 1 AND 500),
  ADD CONSTRAINT chk_books_author
    CHECK (author IS NULL OR char_length(author) <= 500),
  ADD CONSTRAINT chk_books_description
    CHECK (description IS NULL OR char_length(description) <= 10000),
  ADD CONSTRAINT chk_books_cover_url
    CHECK (cover_url IS NULL OR char_length(cover_url) <= 2048),
  ADD CONSTRAINT chk_books_genre
    CHECK (genre IS NULL OR char_length(genre) <= 100),
  ADD CONSTRAINT chk_books_source
    CHECK (source IS NULL OR source IN ('kindle', 'google_books', 'manual', 'scan'));

-- ============================================================================
-- 3. READING_GROUPS
-- ============================================================================
ALTER TABLE reading_groups
  ADD CONSTRAINT chk_groups_name
    CHECK (char_length(trim(name)) BETWEEN 1 AND 100),
  ADD CONSTRAINT chk_groups_description
    CHECK (description IS NULL OR char_length(description) <= 1000);

-- ============================================================================
-- 4. GROUP_CHALLENGES
-- ============================================================================
ALTER TABLE group_challenges
  ADD CONSTRAINT chk_challenges_title
    CHECK (char_length(trim(title)) BETWEEN 1 AND 200),
  ADD CONSTRAINT chk_challenges_description
    CHECK (description IS NULL OR char_length(description) <= 1000);

-- ============================================================================
-- 5. COMMENTS
-- ============================================================================
ALTER TABLE comments
  ADD CONSTRAINT chk_comments_content
    CHECK (char_length(trim(content)) BETWEEN 1 AND 2000);

-- ============================================================================
-- 6. USER_CUSTOM_LISTS
-- ============================================================================
ALTER TABLE user_custom_lists
  ADD CONSTRAINT chk_custom_lists_title
    CHECK (char_length(trim(title)) BETWEEN 1 AND 100);

-- ============================================================================
-- 7. REACTIONS
-- ============================================================================
ALTER TABLE reactions
  ADD CONSTRAINT chk_reactions_type
    CHECK (char_length(reaction_type) BETWEEN 1 AND 50);

-- ============================================================================
-- 8. NOTIFICATIONS
-- ============================================================================
ALTER TABLE notifications
  ADD CONSTRAINT chk_notifications_type
    CHECK (char_length(type) BETWEEN 1 AND 50);

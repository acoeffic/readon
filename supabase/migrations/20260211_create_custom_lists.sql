-- Migration: Custom user reading lists
-- Allows users to create their own reading lists with books from their library

-- Table for custom lists
CREATE TABLE user_custom_lists (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title      text NOT NULL,
  icon_name  text NOT NULL DEFAULT 'book-open',
  gradient_color text NOT NULL DEFAULT '#7FA497',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE user_custom_lists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own custom lists"
ON user_custom_lists FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own custom lists"
ON user_custom_lists FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own custom lists"
ON user_custom_lists FOR UPDATE TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own custom lists"
ON user_custom_lists FOR DELETE TO authenticated
USING (auth.uid() = user_id);

CREATE INDEX idx_user_custom_lists_user_id ON user_custom_lists(user_id);

-- Junction table for books in custom lists
CREATE TABLE user_custom_list_books (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  list_id    bigint NOT NULL REFERENCES user_custom_lists(id) ON DELETE CASCADE,
  book_id    bigint NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  position   int NOT NULL DEFAULT 0,
  added_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(list_id, book_id)
);

ALTER TABLE user_custom_list_books ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view books in their own lists"
ON user_custom_list_books FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_custom_lists
    WHERE user_custom_lists.id = user_custom_list_books.list_id
    AND user_custom_lists.user_id = auth.uid()
  )
);

CREATE POLICY "Users can add books to their own lists"
ON user_custom_list_books FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_custom_lists
    WHERE user_custom_lists.id = user_custom_list_books.list_id
    AND user_custom_lists.user_id = auth.uid()
  )
);

CREATE POLICY "Users can update books in their own lists"
ON user_custom_list_books FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_custom_lists
    WHERE user_custom_lists.id = user_custom_list_books.list_id
    AND user_custom_lists.user_id = auth.uid()
  )
);

CREATE POLICY "Users can remove books from their own lists"
ON user_custom_list_books FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_custom_lists
    WHERE user_custom_lists.id = user_custom_list_books.list_id
    AND user_custom_lists.user_id = auth.uid()
  )
);

CREATE INDEX idx_user_custom_list_books_list_id ON user_custom_list_books(list_id);
CREATE INDEX idx_user_custom_list_books_book_id ON user_custom_list_books(book_id);

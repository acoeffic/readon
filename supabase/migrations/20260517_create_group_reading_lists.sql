-- Migration: Group reading lists (bibliothèques de club)
-- Permet aux membres d'un club de créer et partager des listes de lecture.
-- Tous les membres peuvent ajouter un livre. Un membre peut retirer ce qu'il
-- a ajouté ; un admin peut tout retirer.

-- ──────────────────────────────────────────────────────────────────────
-- Table: group_reading_lists
-- ──────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS group_reading_lists (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id        uuid NOT NULL REFERENCES reading_groups(id) ON DELETE CASCADE,
  created_by      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text,
  icon_name       text NOT NULL DEFAULT 'book-open',
  gradient_color  text NOT NULL DEFAULT '#7FA497',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE group_reading_lists ENABLE ROW LEVEL SECURITY;

-- SELECT : tous les membres du club peuvent voir les listes.
DROP POLICY IF EXISTS "Members can view group reading lists" ON group_reading_lists;
CREATE POLICY "Members can view group reading lists"
ON group_reading_lists FOR SELECT TO authenticated
USING (is_group_member(group_id, auth.uid()));

-- INSERT : tous les membres du club peuvent créer une liste.
DROP POLICY IF EXISTS "Members can create group reading lists" ON group_reading_lists;
CREATE POLICY "Members can create group reading lists"
ON group_reading_lists FOR INSERT TO authenticated
WITH CHECK (
  is_group_member(group_id, auth.uid())
  AND created_by = auth.uid()
);

-- UPDATE : créateur de la liste OU admin du club.
DROP POLICY IF EXISTS "Creator or admin can update list" ON group_reading_lists;
CREATE POLICY "Creator or admin can update list"
ON group_reading_lists FOR UPDATE TO authenticated
USING (
  created_by = auth.uid()
  OR is_group_admin(group_id, auth.uid())
)
WITH CHECK (
  created_by = auth.uid()
  OR is_group_admin(group_id, auth.uid())
);

-- DELETE : créateur de la liste OU admin du club.
DROP POLICY IF EXISTS "Creator or admin can delete list" ON group_reading_lists;
CREATE POLICY "Creator or admin can delete list"
ON group_reading_lists FOR DELETE TO authenticated
USING (
  created_by = auth.uid()
  OR is_group_admin(group_id, auth.uid())
);

CREATE INDEX IF NOT EXISTS idx_group_reading_lists_group_id
  ON group_reading_lists(group_id);
CREATE INDEX IF NOT EXISTS idx_group_reading_lists_created_by
  ON group_reading_lists(created_by);

-- ──────────────────────────────────────────────────────────────────────
-- Table: group_reading_list_books (junction)
-- ──────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS group_reading_list_books (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  list_id    bigint NOT NULL REFERENCES group_reading_lists(id) ON DELETE CASCADE,
  book_id    bigint NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  added_by   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  position   int NOT NULL DEFAULT 0,
  added_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(list_id, book_id)
);

ALTER TABLE group_reading_list_books ENABLE ROW LEVEL SECURITY;

-- Helper inline : récupérer le group_id parent d'une list_id.
-- On l'utilise via un EXISTS dans les policies plutôt que via une
-- fonction supplémentaire, pour rester simple.

-- SELECT : tous les membres du club peuvent voir les livres des listes.
DROP POLICY IF EXISTS "Members can view list books" ON group_reading_list_books;
CREATE POLICY "Members can view list books"
ON group_reading_list_books FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM group_reading_lists l
    WHERE l.id = group_reading_list_books.list_id
      AND is_group_member(l.group_id, auth.uid())
  )
);

-- INSERT : tous les membres peuvent ajouter un livre à n'importe quelle
-- liste du club (added_by doit être l'utilisateur courant).
DROP POLICY IF EXISTS "Members can add books to list" ON group_reading_list_books;
CREATE POLICY "Members can add books to list"
ON group_reading_list_books FOR INSERT TO authenticated
WITH CHECK (
  added_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM group_reading_lists l
    WHERE l.id = group_reading_list_books.list_id
      AND is_group_member(l.group_id, auth.uid())
  )
);

-- UPDATE : seulement pour réordonner, par l'utilisateur qui a ajouté ou
-- par un admin du club (utile si on ajoute du drag-and-drop plus tard).
DROP POLICY IF EXISTS "Adder or admin can update list book" ON group_reading_list_books;
CREATE POLICY "Adder or admin can update list book"
ON group_reading_list_books FOR UPDATE TO authenticated
USING (
  added_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM group_reading_lists l
    WHERE l.id = group_reading_list_books.list_id
      AND is_group_admin(l.group_id, auth.uid())
  )
)
WITH CHECK (
  added_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM group_reading_lists l
    WHERE l.id = group_reading_list_books.list_id
      AND is_group_admin(l.group_id, auth.uid())
  )
);

-- DELETE : celui qui a ajouté le livre OU un admin du club.
DROP POLICY IF EXISTS "Adder or admin can remove list book" ON group_reading_list_books;
CREATE POLICY "Adder or admin can remove list book"
ON group_reading_list_books FOR DELETE TO authenticated
USING (
  added_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM group_reading_lists l
    WHERE l.id = group_reading_list_books.list_id
      AND is_group_admin(l.group_id, auth.uid())
  )
);

CREATE INDEX IF NOT EXISTS idx_group_reading_list_books_list_id
  ON group_reading_list_books(list_id);
CREATE INDEX IF NOT EXISTS idx_group_reading_list_books_book_id
  ON group_reading_list_books(book_id);
CREATE INDEX IF NOT EXISTS idx_group_reading_list_books_added_by
  ON group_reading_list_books(added_by);

-- ──────────────────────────────────────────────────────────────────────
-- Auto-update trigger for updated_at
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION touch_group_reading_lists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_group_reading_lists_touch ON group_reading_lists;
CREATE TRIGGER trg_group_reading_lists_touch
  BEFORE UPDATE ON group_reading_lists
  FOR EACH ROW
  EXECUTE FUNCTION touch_group_reading_lists_updated_at();

-- ──────────────────────────────────────────────────────────────────────
-- RPC: get_group_reading_lists
-- Renvoie les listes d'un club avec : nombre de livres, jusqu'à 4 URL de
-- couvertures (pour vignette empilée), nom du créateur.
-- ──────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS get_group_reading_lists(UUID) CASCADE;
CREATE OR REPLACE FUNCTION get_group_reading_lists(p_group_id UUID)
RETURNS TABLE (
  id              bigint,
  group_id        uuid,
  created_by      uuid,
  creator_name    text,
  title           text,
  description     text,
  icon_name       text,
  gradient_color  text,
  book_count      bigint,
  cover_urls      text[],
  created_at      timestamptz,
  updated_at      timestamptz
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    l.id,
    l.group_id,
    l.created_by,
    p.display_name AS creator_name,
    l.title,
    l.description,
    l.icon_name,
    l.gradient_color,
    COALESCE(books_agg.cnt, 0) AS book_count,
    COALESCE(books_agg.covers, ARRAY[]::text[]) AS cover_urls,
    l.created_at,
    l.updated_at
  FROM group_reading_lists l
  LEFT JOIN profiles p ON p.id = l.created_by
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*) AS cnt,
      ARRAY_AGG(b.cover_url ORDER BY lb.position, lb.added_at)
        FILTER (WHERE b.cover_url IS NOT NULL) AS covers
    FROM group_reading_list_books lb
    JOIN books b ON b.id = lb.book_id
    WHERE lb.list_id = l.id
  ) books_agg ON TRUE
  WHERE l.group_id = p_group_id
    AND is_group_member(p_group_id, auth.uid())
  ORDER BY l.updated_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_group_reading_lists(UUID) TO authenticated;

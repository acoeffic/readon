-- club_cover_library : bibliothèque curée de couvertures pour les clubs.
-- Les utilisateurs n'uploadent plus leur propre image — ils choisissent dans
-- cette liste. L'admin (toi) ajoute des rows en uploadant l'image dans le
-- bucket Storage `asset` puis en insérant l'URL ici.

CREATE TABLE IF NOT EXISTS club_cover_library (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url TEXT NOT NULL,
  name TEXT,
  category TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_cover_library_sort
  ON club_cover_library (is_active, category, sort_order);

ALTER TABLE club_cover_library ENABLE ROW LEVEL SECURITY;

-- Lecture publique : tout utilisateur authentifié peut lister les covers
DROP POLICY IF EXISTS "club_cover_library_read_authenticated" ON club_cover_library;
CREATE POLICY "club_cover_library_read_authenticated"
  ON club_cover_library
  FOR SELECT
  TO authenticated
  USING (is_active = TRUE);

-- Pas de policies INSERT/UPDATE/DELETE pour authenticated → seul un service
-- role (toi via dashboard) peut modifier la lib.

-- ── Seed initial ────────────────────────────────────────────────────────

INSERT INTO club_cover_library (url, name, category, sort_order)
VALUES (
  'https://nzbhmshkcwudzydeahrq.supabase.co/storage/v1/object/public/asset/Image/club_cover/ChatGPT%20Image%207%20mai%202026,%2023_12_41%20(2).png',
  'Cover #1',
  NULL,
  0
)
ON CONFLICT DO NOTHING;

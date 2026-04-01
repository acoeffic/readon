-- Literary prizes: curated lists from Wikidata + Open Library

-- Prize configurations (which prizes to sync)
CREATE TABLE IF NOT EXISTS prize_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prize_name TEXT NOT NULL,
  wikidata_id TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO prize_configs (prize_name, wikidata_id) VALUES
  ('Prix Goncourt',                          'Q163020'),
  ('Prix Renaudot',                          'Q275407'),
  ('Prix Femina',                            'Q253220'),
  ('Prix Médicis',                           'Q240113'),
  ('Grand Prix du Roman de l''Académie fr.', 'Q373612'),
  ('Booker Prize',                           'Q160082'),
  ('Prix Nobel de Littérature',              'Q37922')
ON CONFLICT (wikidata_id) DO NOTHING;

-- Curated lists (one per prize+year combo)
CREATE TABLE IF NOT EXISTS prize_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  prize_name TEXT NOT NULL,
  prize_wikidata_id TEXT NOT NULL,
  list_type TEXT NOT NULL CHECK (list_type IN ('prize_year', 'thematic')),
  year INT,
  cover_url TEXT,
  is_active BOOLEAN DEFAULT true,
  last_synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_prize_year UNIQUE (prize_wikidata_id, year, list_type)
);

-- Books within prize lists
CREATE TABLE IF NOT EXISTS prize_list_books (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID REFERENCES prize_lists(id) ON DELETE CASCADE,
  isbn TEXT,
  wikidata_book_id TEXT,
  title TEXT NOT NULL,
  author TEXT,
  cover_url TEXT,
  description TEXT,
  page_count INT,
  publication_year INT,
  open_library_id TEXT,
  position INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(list_id, wikidata_book_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prize_lists_prize ON prize_lists(prize_wikidata_id);
CREATE INDEX IF NOT EXISTS idx_prize_list_books_list ON prize_list_books(list_id);

-- RLS: public read, write via service_role only
ALTER TABLE prize_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE prize_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE prize_list_books ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read prize_configs" ON prize_configs;
CREATE POLICY "Public read prize_configs"
  ON prize_configs FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read prize_lists" ON prize_lists;
CREATE POLICY "Public read prize_lists"
  ON prize_lists FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Public read prize_list_books" ON prize_list_books;
CREATE POLICY "Public read prize_list_books"
  ON prize_list_books FOR SELECT USING (true);

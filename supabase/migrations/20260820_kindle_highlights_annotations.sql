-- Highlights Kindle importés dans les passages (table annotations).
--
-- Les surlignages scrapés depuis read.amazon.com/notebook deviennent des
-- annotations de type 'kindle', fusionnées dans le mur « Mes passages » aux
-- côtés des captures photo. Le sync tourne toutes les 24 h et re-crawle tout :
-- l'idempotence repose entièrement sur `source_key`.
--
-- `source_key` : clé de déduplication stable, construite côté client :
--   'kindle:<asin>:<id d'annotation Amazon>' quand Amazon fournit l'id de ligne,
--   sinon 'kindle:<asin>:<location>:<hash du texte>'.
-- L'index unique est TOTAL (pas partiel) : PostgREST ne sait pas inférer un
-- index partiel pour `ON CONFLICT`, et en Postgres les NULLs sont distincts
-- par défaut — les annotations photo/texte/voix existantes (source_key NULL)
-- ne sont donc pas contraintes.
--
-- `note` : la note personnelle qu'Amazon attache à un surlignage (facultative).

ALTER TABLE public.annotations
  DROP CONSTRAINT IF EXISTS annotations_type_check;

ALTER TABLE public.annotations
  ADD CONSTRAINT annotations_type_check
  CHECK (type = ANY (ARRAY['text'::text, 'photo'::text, 'voice'::text, 'kindle'::text]));

ALTER TABLE public.annotations
  ADD COLUMN IF NOT EXISTS source_key text;

ALTER TABLE public.annotations
  ADD COLUMN IF NOT EXISTS note text;

CREATE UNIQUE INDEX IF NOT EXISTS annotations_user_source_key_key
  ON public.annotations (user_id, source_key);

COMMENT ON COLUMN public.annotations.source_key IS
  'Clé de déduplication des passages importés (highlights Kindle). NULL pour les annotations créées dans l''app.';
COMMENT ON COLUMN public.annotations.note IS
  'Note personnelle attachée au surlignage (import Kindle).';

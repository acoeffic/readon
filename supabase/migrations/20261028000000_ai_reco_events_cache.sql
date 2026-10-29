-- 2026-10-28 — Recommandations IA du feed : mesure + cache serveur.
-- Contexte : ai-suggest-books était appelé à chaque chargement du feed (gpt-4o),
-- sans cache, et le quota gratuit (5/mois) partait en silence. Aucun suivi
-- n'existait pour savoir si une reco est vue, ouverte ou ajoutée.
-- Migration purement additive (2 tables), rien d'existant n'est modifié.

-- 1) Événements de reco (affichée / ouverte / ajoutée / clic Amazon).
--    Écrits par le client (INSERT own-rows uniquement), lus via service_role / MCP.
CREATE TABLE IF NOT EXISTS public.ai_reco_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  event       text NOT NULL CHECK (event IN ('shown', 'opened', 'added', 'amazon')),
  source      text NOT NULL CHECK (char_length(source) <= 40),   -- type de suggestion : aiRecommended, friendsReading, …
  book_key    text NOT NULL CHECK (char_length(book_key) <= 200), -- clé normalisée titre|auteur (ou id/google_id)
  title       text CHECK (char_length(title) <= 300),
  author      text CHECK (char_length(author) <= 300),
  rank        smallint,                                           -- position dans le carrousel (0 = première)
  event_day   date NOT NULL DEFAULT ((now() AT TIME ZONE 'Europe/Paris')::date),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Une seule ligne par (utilisateur, événement, livre, jour) : le feed se
-- rafraîchit souvent, on ne veut pas compter 20 « shown » du même livre.
CREATE UNIQUE INDEX IF NOT EXISTS ai_reco_events_dedup_idx
  ON public.ai_reco_events (user_id, event, book_key, event_day);
CREATE INDEX IF NOT EXISTS ai_reco_events_created_idx
  ON public.ai_reco_events (created_at DESC);

ALTER TABLE public.ai_reco_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_reco_events FROM anon, authenticated;
GRANT INSERT ON public.ai_reco_events TO authenticated;

DROP POLICY IF EXISTS ai_reco_events_insert_own ON public.ai_reco_events;
CREATE POLICY ai_reco_events_insert_own ON public.ai_reco_events
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
-- Volontairement aucune policy SELECT/UPDATE/DELETE : lecture réservée à service_role.

-- 2) Cache serveur des recos IA (une ligne par utilisateur), lu/écrit uniquement
--    par l'Edge Function ai-suggest-books (service_role).
CREATE TABLE IF NOT EXISTS public.ai_reco_cache (
  user_id      uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  suggestions  jsonb NOT NULL DEFAULT '[]'::jsonb,
  locale       text NOT NULL DEFAULT 'fr',
  limit_count  smallint NOT NULL DEFAULT 5,
  generated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_reco_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_reco_cache FROM anon, authenticated;
-- RLS activée sans policy = deny-all voulu (même schéma que audit_log) : ne pas « corriger ».

COMMENT ON TABLE public.ai_reco_events IS 'Funnel des suggestions du feed : shown/opened/added/amazon par source (voir 20261028000000).';
COMMENT ON TABLE public.ai_reco_cache IS 'Cache 24 h des recos IA par utilisateur, écrit par ai-suggest-books (service_role).';

-- ROLLBACK : DROP TABLE public.ai_reco_events; DROP TABLE public.ai_reco_cache;

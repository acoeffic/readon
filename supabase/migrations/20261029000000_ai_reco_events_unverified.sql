-- 2026-10-29 — Muse chat : mesurer les livres cités introuvables sur Google Books
-- (titres probablement inventés par le modèle). Ajoute l'événement 'unverified'
-- à la contrainte existante. Additif, aucune donnée modifiée.
ALTER TABLE public.ai_reco_events DROP CONSTRAINT IF EXISTS ai_reco_events_event_check;
ALTER TABLE public.ai_reco_events ADD CONSTRAINT ai_reco_events_event_check
  CHECK (event IN ('shown', 'opened', 'added', 'amazon', 'unverified'));

-- ROLLBACK : remettre la contrainte sans 'unverified' (supprimer d'abord les lignes unverified).

-- Exception ciblée à la règle du 22/07/2026 ("anon sans EXECUTE sur les RPC") :
-- le mode invité (lib/providers/guest_mode_provider.dart, feed_page.dart
-- _loadGuestFeed) appelle bel et bien 2 RPC SECURITY DEFINER en pré-login
-- pour ses 3 sections publiques (clubs publics, livres tendances) :
--   - get_public_groups   → GroupsService.getPublicGroups() : Erreur "Groupe
--     introuvable" / PostgrestException 42501 vue en prod le 14/09/2026.
--   - get_trending_books_by_sessions → TrendingService.getTrendingBooks() :
--     échouait en silence (try/catch → []) donc jamais remarqué, mais casse
--     la section "livres tendances" du feed invité.
-- Ces deux fonctions ne retournent que du contenu déjà public (clubs
-- is_private = false, agrégats de livres sans PII) : le grant n'élargit pas
-- la surface de données, il aligne les grants sur ce que les policies RLS
-- anon (migration 20260516_guest_mode_public_access) autorisent déjà par
-- ailleurs en accès direct aux tables.
GRANT EXECUTE ON FUNCTION public.get_public_groups(integer, integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_trending_books_by_sessions(integer) TO anon;

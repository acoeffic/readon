-- Audit 14/08/2026 : `kindle_sync` a RLS activée avec des policies SELECT,
-- INSERT et UPDATE — mais AUCUNE policy DELETE. Le
-- `.delete().eq('user_id', …)` de `KindleWebViewService.disconnect()`
-- supprimait donc 0 ligne, et PostgREST renvoie 204 sans erreur : l'app
-- confirmait « Kindle déconnecté » alors que les streaks et `books_data`
-- (titres lus) restaient en base indéfiniment. Enjeu RGPD.

create policy "Users can delete own kindle data"
  on public.kindle_sync
  for delete
  to authenticated
  using (auth.uid() = user_id);

grant delete on public.kindle_sync to authenticated;

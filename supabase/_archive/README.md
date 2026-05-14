# Archive — scripts SQL hors-migrations

Ces fichiers ne sont **pas** des migrations Supabase :
- ils ne suivent pas le pattern `<timestamp>_name.sql` requis par la CLI
- ils étaient skippés par `supabase db push` à chaque exécution
- ils polluaient le dossier `supabase/migrations/`

Déplacés ici pour archive. Trois catégories :

## 🔧 Fixes ad-hoc anciens (superseded)
Corrections appliquées avant la mise en place du système de migrations timestampées. Le schéma a évolué depuis via des migrations propres.
- `fix_books_rls_policies.sql`
- `fix_reading_sessions_rls_policies.sql`
- `fix_user_books_rls_policies.sql`
- `fix_user_search_function.sql`
- `fix_user_search_function_v2.sql`

## 🔍 Scripts de debug / audit
Utilisés ponctuellement pour investiguer des incidents spécifiques. À ne **jamais** re-jouer en prod :
- `check_function_exists.sql`
- `check_privacy_status.sql`
- `check_user_badges_structure.sql`
- `debug_charles_issue.sql`
- `test_charles_data.sql`
- `test_charles_rpc.sql`

## 📦 Drafts / superseded data
Anciennes versions intégrées dans des migrations timestampées plus récentes :
- `add_streak_badges.sql` → repris dans `20260201_complete_badges_system.sql`
- `add_user_search_features.sql` → repris dans les migrations user-search timestampées

## 📄 Ancien README
`OLD_README.md` est l'ancien README qui était dans `migrations/`, conservé pour mémoire (il décrivait les instructions d'installation manuelles d'avant le système CLI).

---

## ⚠️ Si tu veux rejouer un de ces fichiers
1. Vérifie qu'il est encore d'actualité (le schéma a beaucoup évolué)
2. Renomme-le en `<YYYYMMDD>_descriptif.sql`
3. Bouge-le dans `supabase/migrations/`
4. `supabase db push`

## ⚠️ Si tu veux supprimer le dossier
C'est OK — la prod a déjà tout ce qu'il faut via les migrations timestampées dans `migrations/`. Ces archives n'ont qu'une valeur historique.

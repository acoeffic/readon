# Audit migrations Supabase

> Lecture-seule — état des lieux des 135 migrations dans `migrations/`. Aucun fichier n'a été supprimé ni renommé. Ce doc sert de mental model pour comprendre l'état courant.

## Vue d'ensemble

**135 migrations** organisées par grands domaines :

| Domaine | Nb | Range temporel |
|---|---|---|
| Foundation / RLS | 1 | `00_complete_rls_setup.sql` |
| Auth / profils | ~8 | jan-mai 2026 |
| Notifications | ~17 | jan-mai 2026 (beaucoup de fix incrémentaux) |
| Badges (système + données) | ~25 | jan-mai 2026 |
| Feed / activités | ~13 | jan-mai 2026 |
| Reading sessions | ~10 | jan-mai 2026 |
| Groups / clubs | ~10 | jan-mai 2026 |
| Genres badges | ~14 | fév-mai 2026 |
| Wrapped (monthly + yearly) | ~4 | fév-mai 2026 |
| PYMK / suggestions | ~6 | fév-mai 2026 |
| Moderation | ~5 | avr-mai 2026 |
| Premium / RevenueCat | 1 | fév 2026 |
| Storage buckets | ~4 | fév-mai 2026 |
| Performance / indexes | ~3 | fév-mar 2026 |
| Anti-cheat | 2 | fév + mai 2026 |
| Divers (audit, AI chat, annotations, etc.) | ~12 | jan-mai 2026 |

---

## 🔁 Supersessions confirmées par lecture du code

Ces paires/triples touchent la **même fonction ou table**. La version la plus récente est le code "vivant" sur la prod ; les précédentes sont conservées pour l'historique mais leur SQL a été remplacé.

### `check_and_award_badges()` — fonction badge engine
1. `20260201_complete_badges_system.sql` — création initiale
2. `20260216_speed_cap_anticheat.sql` — recréée (a perdu le `ON CONFLICT`)
3. `20260316_fix_badges_on_conflict.sql` — réintroduit `ON CONFLICT` + contrainte unique
4. `20260407_fix_badges_on_conflict.sql` — réintroduit encore (avait été reperdu) + ajoute les badges Comeback
5. `20260426_fix_check_and_award_badges.sql` — fix `reading_goals.is_completed` n'existe pas + `comments.author_id`
6. `20260427000001_fix_check_and_award_badges_ambiguous.sql` ✅ **état actuel** — fix ambiguïté `badge_id` via `#variable_conflict use_column`

→ Si tu veux lire le code actuel de la fonction : **20260427000001**.

### `get_user_notifications()` — RPC notifications
1. `20260315_notification_center.sql` — création
2. `20260403000000_fix_notification_book_title.sql` — fix book_title manquant
3. `20260422_fix_get_user_notifications_column.sql` — fix nom colonne
4. `20260429_fix_notification_book_title_and_enrich_payload.sql` ✅ **état actuel** — restore + enrichit le payload (session_id, book_id, etc.)

→ Code actuel : **20260429**.

### `get_feed_bundle()` — RPC feed agrégée
1. `20260509_get_feed_bundle.sql` — création (Fan-Out On Write)
2. `20260510000002_drop_old_feed_bundle.sql` ✅ — drop l'ancienne fonction `get_combined_feed` après bascule

→ Le bundle est créé en `20260509`, l'ancien drop en `20260510`. Pas une supersession à proprement parler, c'est une transition propre.

### Genre badges
Plusieurs ajouts puis retraits :
1. `20260328` → polar, `20260329` → SF, `20260330` → SF tiers
2. `20260331_add_occasion_badges.sql`
3. `20260404` → histoire, `20260405000000` → horreur, `20260406` → romance
4. `20260414_remove_old_genre_master_badges.sql` — supprime les anciens "Maître de X"
5. `20260415_remove_reading_speed_badges.sql` — supprime des badges de vitesse
6. `20260224` → biographie, `20260227` → devperso
7. `20260519_add_genre_thriller_fantasy_badges.sql` ✅ — ajoute thriller + fantasy (état actuel pour les genres)

→ Pas de supersession brute, c'est un historique d'ajouts/retraits.

### PYMK / Suggested readers
1. `20260218_contacts_friend_suggestions.sql` — base contacts
2. `20260402_onboarding_suggested_readers.sql` — première RPC `get_suggested_readers`
3. `20260501000001_suggested_readers_exclude_friends.sql` — fix : exclure amis/pending
4. `20260501000002_get_people_you_may_know.sql` — nouvelle RPC multi-signal
5. `20260520000002_fix_pymk_ambiguous_user_id.sql` — fix ambiguïté `user_id`
6. `20260520000003_pymk_remove_reading_flows_ref.sql` ✅ **état actuel** — remplace réf morte `reading_flows` par `0::INTEGER` (à la fois sur PYMK et suggested_readers)

→ Code actuel des 2 RPCs : **20260520000003**.

### `mutual_friends` / `get_mutual_friends_summary()`
- `20260522_get_mutual_friends_summary.sql` ✅ — RPC actuel

### Feed materialized views (isbn / google_id)
- `20260521_add_isbn_googleid_to_feed_mvs.sql` ✅ — recrée `mv_trending_books` avec isbn/google_id

### Auto-moderation
- `20260410_ai_moderated_comments.sql` — première version (commentaires)
- `20260518_auto_moderate_comments.sql` — refonte commentaires
- `20260524000002_auto_moderate_avatars.sql` — étend aux avatars
- `20260524000003_auto_moderate_display_name.sql` — étend aux display names
→ Pas de supersession, c'est une extension progressive du périmètre.

---

## 🚫 Pas de supersession claire (à priori)

Ces migrations qui ont des noms qui pourraient suggérer un doublon, mais qui font en réalité des choses différentes :
- `20260205_fix_feed_functions.sql` (early) — pas superseded ; les migrations feed plus tardives (`20260307`, `20260324`, `20260507-509`) sont des évolutions d'architecture (pagination → MV → fan-out), pas des fixes du même code.
- Les ~17 fixes notifications — chacun corrige un bug distinct (timezone, colonnes, payload, types, dedup, etc.), pas de duplication.

---

## ✅ Recommandations

1. **Aucune action requise**. Toutes les migrations sont valides et appliquées. Les supersessions documentées ci-dessus sont normales — c'est l'historique du schéma.
2. **Pour lire l'état actuel d'une fonction** : référence le tableau ci-dessus, va directement à la migration "état actuel" plutôt que de lire la chaîne.
3. **Pour ajouter un fix** : crée une nouvelle migration timestampée plutôt que de modifier une ancienne (les anciennes sont la photo historique, ne jamais les toucher).
4. **Si tu veux squash** un jour (compresser tout en un schéma propre) : Supabase a `supabase db dump` qui peut générer un fichier unique consolidé. Mais ça casse l'historique → à faire seulement si le projet repart de zéro côté dev DB.

---

## 📊 Pour les curieux

Pour voir l'évolution d'une feature précise dans le temps :

```bash
# Toutes les migrations badges, dans l'ordre
cd supabase/migrations
ls *badges* *check_and_award* | sort

# Toutes les migrations feed
ls *feed* | sort

# Toutes les migrations notifications
ls *notif* | sort
```

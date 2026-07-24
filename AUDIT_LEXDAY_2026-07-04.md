# Audit LexDay — bugs & sécurité

_04 juillet 2026 · périmètre : code Flutter (`lib/`), Edge Functions Supabase, base de données (advisors/RLS)._

Audit en lecture seule. Aucun fichier modifié. Les findings ci-dessous ont été confirmés par lecture du code (ou par les advisors Supabase officiels). Les deux plus critiques (#1, #2) ont été re-vérifiés manuellement.

---

## 🔴 Critique — à corriger avant tout

### 1. Relais d'e-mail ouvert — `send-comment-email`
`supabase/functions/send-comment-email/index.ts:37-55`. La fonction n'a aucune auth d'appelant réelle : `verify_jwt` accepte la clé **anon** embarquée dans l'app mobile. `to_email` et `comment` sont entièrement contrôlés par l'appelant et injectés dans un e-mail au branding LexDay envoyé via Resend depuis `hello@lexday.fr`.

**Impact** : quiconque extrait la clé anon (triviale sur mobile) peut envoyer des e-mails arbitraires (phishing/spam) vers n'importe quelle adresse, en brûlant le quota Resend et la réputation du domaine `lexday.fr`.
**Fix** : n'autoriser l'appel que via le trigger SQL (secret partagé / service-role vérifié en code, comme `send-streak-reminders`), pas via le gateway JWT. Le HTML est déjà correctement échappé (`escapeHtml`), ce n'est donc pas un problème d'injection ici mais de contrôle d'accès.

### 2. Contournement de modération / IDOR — `moderate-comment`
`supabase/functions/moderate-comment/index.ts:40-63`. La fonction vérifie seulement la *présence* d'un header Authorization (l.40-43), puis met à jour `comments.status` via la service-role en se basant sur le `comment_id` fourni dans le body, **sans aucun contrôle de propriété ni d'état**.

**Impact** : un porteur de la clé anon peut forcer `approved` sur n'importe quel commentaire en attente/flaggé, ou manipuler les commentaires d'autres utilisateurs — la modération IA est entièrement court-circuitée.
**Fix** : dériver l'utilisateur du JWT (`auth.getUser()`), vérifier la propriété du commentaire, ou réserver la fonction au trigger interne.

### 3. `ai-suggest-books` sans limite d'usage (abus de coût)
`supabase/functions/ai-suggest-books/index.ts:65-272`. Contrairement à `ai-chat` (plafond `MAX_FREE_MONTHLY_MESSAGES=3`), cette fonction n'a **ni check premium ni plafond mensuel**. Chaque appel déclenche une requête `gpt-4o` (cher).

**Impact** : n'importe quel utilisateur authentifié peut l'appeler en boucle → coût OpenAI incontrôlé.
**Fix** : ajouter le même quota que `ai-chat`.

---

## 🟠 Haute

### 4. `setState` / `BuildContext` après `await` sans `mounted` (~41 sites)
Pattern répandu, pires cas confirmés :
- `lib/pages/reading/end_reading_session_page.dart:122-124, 143-145` — `setState` + lookup de contexte dans le `catch` après `pickImage(camera)`. La caméra peut démonter la page (Android tue l'activité) → crash `setState after dispose`.
- `lib/pages/books/scan_book_cover_page.dart:117-130, 178, 194, 215, 227, 242` — page caméra, `setState` après chaque `await` réseau sans garde.
- Idem `notifications_page.dart:41-49`, `groups_page.dart:56/74`, `group_detail_page.dart:61/144/157`, `challenge_detail_page.dart`, `auth_gate.dart:44`, `all_badges_page.dart:42`.
**Fix** : `if (!mounted) return;` après chaque `await` avant tout `setState`/usage de `context`.

### 5. `currentUser!.id` non gardé dans le flux offline
`lib/services/offline_session_queue.dart:28`. `_supabase.auth.currentUser!.id` : si la session locale a expiré/été purgée (précisément le cas offline visé), crash null-check et perte de la session de lecture. Même pattern dans `annotation_service.dart:62/163/189`, `goals_service.dart:56/112`, `reading_session_service.dart` (plusieurs lignes).
**Fix** : garder l'accès et échouer proprement / re-queue.

### 6. Vue exposée en `SECURITY DEFINER` (advisor ERROR)
Advisor Supabase, niveau **ERROR** : `friend_activity_view` est une vue `SECURITY DEFINER` → elle contourne la RLS de l'appelant et s'exécute avec les droits du créateur. Risque de fuite d'activité entre utilisateurs.
[Doc](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view)

### 7. Policies RLS « always true » sur données utilisateur
Advisor : `rls_policy_always_true` sur `books` et **`user_badges`**. Une policy `USING (true)` sur `user_badges` rend les badges de tous les utilisateurs lisibles/modifiables sans restriction. À vérifier (acceptable pour `books` catalogue public, douteux pour `user_badges`).

---

## 🟡 Moyenne

### 8. `send-wrapped-notification` cassée (silencieusement)
`supabase/functions/send-wrapped-notification/index.ts:6-9, 45-68`. `getAccessToken()` est un stub vide → `Bearer undefined` sur chaque appel FCM → tout échoue. Pire : `response.ok` n'est jamais testé, `sent++` compte les échecs comme succès. Le push Wrapped mensuel n'est jamais délivré tout en rapportant un succès.

### 9. Injection HTML — `send-friend-request-email`
`supabase/functions/send-friend-request-email/index.ts:58,63,65,73`. `display_name` interpolé **non échappé** dans le HTML de l'e-mail (contrairement à `send-comment-email`). La modération de `display_name` ne filtre pas le markup → injection de liens/HTML possible.

### 10. Crons appelables par n'importe qui — `refresh-covers`, `sync-literary-prizes`
`refresh-covers/index.ts:267`, `sync-literary-prizes/index.ts:133` : `serve(async (_req) => …)`, zéro auth en code. Déclenchables à la demande par tout porteur de clé anon → martèlement des API externes (Google Books, BnF, Wikidata) et écritures massives sur `books`/`lists`.
**Fix** : valider `CRON_SECRET` en code (comme `send-streak-reminders`).

### 11. IDOR + credentials en clair — `sync_kindle`
`supabase/functions/sync_kindle/index.ts:34,82-93`. `user_id` pris du **body** (pas du JWT) + service-role → ciblage d'un `user_id` arbitraire. Accepte aussi email/mot de passe Amazon en clair dans le body. Inerte aujourd'hui (`loginToAmazon` throw), mais à ne pas expédier tel quel.

### 12. Context après await dans le flux d'achat — `upgrade_page`
`lib/pages/profile/upgrade_page.dart:137-147` (`_restorePurchases`) : `ScaffoldMessenger`/`Navigator` utilisés après un `await` sans re-check `mounted`, alors que `_purchase` juste au-dessus le fait correctement (asymétrie = oubli).

### 13. Controllers jamais disposés (fuites mémoire)
`signup_page.dart:25-27` (3 controllers, pas de `dispose`), `login_page.dart:33-34` (2), `settings_page.dart:544/672` (controllers recréés à chaque dialog).

### 14. Listeners audio empilés — `active_reading_session_page`
`lib/pages/reading/active_reading_session_page.dart:1041-1049` : `playerStateStream.listen(...)` rajouté à **chaque** lecture, subscription jamais annulée → N callbacks `setState` après N lectures.

### 15. Exceptions brutes affichées à l'utilisateur (71 sites)
Ex. `groups_page.dart:62` `Text('Erreur: $e')`. Fuite de détails techniques (messages PostgREST, structure de tables) + violation i18n.

### 16. Vues matérialisées exposées dans l'API + `get_hmac_secret` exécutable par `anon`
Advisor : `mv_community_sessions`, `mv_trending_books` exposées via l'API REST. Et parmi les fonctions `SECURITY DEFINER` exécutables par `anon`, **`get_hmac_secret`** — à auditer d'urgence : si elle renvoie le secret HMAC de hachage des contacts, c'est une fuite critique. À vérifier manuellement.

---

## 🟢 Basse / hygiène

- **~60 fonctions SQL** avec `search_path` mutable (advisor WARN) — durcir avec `SET search_path = ''`.
- **Extensions dans `public`** : `http`, `unaccent` — déplacer vers un schéma dédié.
- **Buckets publics listables** : `groups`, `profiles`, `shares` — désactiver le listing si non voulu.
- **Log de clé API Places** : `lib/services/places_service.dart:74-75` — mettre derrière `kDebugMode`.
- **Pages sans `ConstrainedContent`** (convention iPad CLAUDE.md) : `signup`, `login`, `confirm_email`, `onboarding`, pages légales.
- **Textes FR en dur** (violation i18n) : `scan_book_cover_page`, `user_books_page`, `add_book_to_list_page`, `select_club_cover_page`.
- **Code mort** : `lib/pages/books/start_reading_page.dart` (données factices, non routé).
- Pagination manquante (>1000 lignes) sur `send-streak-reminders:275`, `send-reengagement:246`, `send-wrapped-notification:32`.

---

## ✅ Ce qui est sain

`revenuecat-webhook` vérifie sa signature (comparaison timing-safe). Les fonctions IA utilisateur (`ai-chat`, `summarize-passage`, `transcribe-audio`, `generate-*`, `sync-notion-*`) dérivent bien `user.id` du JWT et appliquent les plafonds free/premium. Aucun secret en dur dans `lib/` ni dans les Edge Functions (tout via `String.fromEnvironment` / `Deno.env.get`). Timers/subscriptions correctement annulés hors des cas listés. `firstWhere` avec `orElse`. `DEV_FORCE_PREMIUM` compile-time à `false`.

## Priorités suggérées
1. **#1 relais e-mail** et **#2 contournement modération** (exploitables trivialement avec la clé anon).
2. **#3 quota `ai-suggest-books`** (coût OpenAI).
3. **#16 `get_hmac_secret`** (vérifier la fuite de secret) et **#6 vue SECURITY DEFINER**.
4. **#4 `mounted`** en masse (crashs réels côté utilisateurs).

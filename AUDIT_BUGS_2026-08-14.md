# Audit LexDay — chasse aux bugs

**Date** : 14 août 2026
**Périmètre** : code Flutter (`lib/`) dans l'état de travail du Mac (HEAD `8fc9355` + les 59 fichiers Dart non commités + 8 nouveaux), Edge Functions et migrations Supabase.
**Méthode** : 6 audits parallèles par dimension, puis une passe de contre-expertise adversariale (chaque bug devait être réfuté avant d'être retenu), puis vérification directe en base de production (`nzbhmshkcwudzydeahrq`) pour tout ce qui touche au schéma, aux droits et aux données.

Ce qui suit ne contient que des bugs vérifiés dans le code ou en base. Les faux positifs éliminés sont listés en fin de document.

---

## 🔴 Critiques — à traiter en premier

### 1. N'importe quel utilisateur peut se rendre Premium — **vérifié en prod**

**Où** : table `profiles` (droits en base, pas dans les migrations du repo)

Le rôle `authenticated` a le `GRANT UPDATE` sur les colonnes `is_premium` **et** `premium_until`, et la policy `Users can update own profile` autorise `USING (auth.uid() = id) WITH CHECK (auth.uid() = id)`. Aucun trigger `BEFORE UPDATE` ne protège ces colonnes (les seuls triggers sur `profiles` concernent l'email, la modération avatar/pseudo, le code de parrainage et la synchro du feed).

Or `profiles.is_premium` est exactement la colonne que lisent **toutes** les Edge Functions premium : `ai-chat`, `generate-reading-sheet`, `transcribe-audio`, `summarize-passage`, `ai-suggest-books`, `sync-notion-reading-sheet`, `notion-oauth-callback`.

**Exploitation** : une ligne, avec la clé anon extraite du binaire et un compte gratuit.
```dart
await supabase.from('profiles').update({'is_premium': true}).eq('id', myId);
```
→ Premium serveur complet et permanent, gratuit. La migration `20260312_drop_sync_client_premium.sql` avait bien verrouillé la table `subscriptions`, mais le cache `profiles.is_premium` est resté ouvert.

**Fix** :
```sql
revoke update on public.profiles from authenticated, anon;
grant update (display_name, avatar_url, fcm_token, is_profile_private, hide_reading_hours,
              notifications_enabled, notification_days, notification_reminder_time,
              notify_comments_email, notify_friend_requests, notify_friend_requests_email,
              email_friend_requests, timezone, reading_habit, onboarding_completed,
              has_seen_contacts_prompt, has_completed_first_session, updated_at)
  on public.profiles to authenticated;
```
(À adapter : la liste actuelle des colonnes ouvertes inclut aussi `id`, `email`, `email_hash`, `referral_code`, `notion_access_token`, `raw_user_meta_data`, `last_sign_in_at` — tous à retirer du grant.)

---

### 2. `moderate-display-name` : usurpation du pseudo de n'importe quel utilisateur

**Où** : `supabase/functions/moderate-display-name/index.ts:111`

La fonction ne vérifie que la **présence** d'un header `Authorization`, puis instancie un client `service_role` et lit `user_id` / `old_value` **dans le body**. `moderate-comment` fait bien un `timingSafeEqual` avec la service_role ; ici, rien. `verify_jwt = true` ne protège pas : la clé anon est un JWT valide signé par le projet, et n'importe quel compte créé en 30 s l'est aussi.

**Exploitation** :
```
POST /functions/v1/moderate-display-name
Authorization: Bearer <n'importe quel token du projet>
{"user_id":"<uuid victime>","new_value":"<insulte>","old_value":"<pseudo choisi par l'attaquant>"}
```
OpenAI flague `new_value` → `rejectDisplayName()` écrit `display_name = old_value` sur le profil de la victime, et le re-trigger de modération le passe en `approved`. **La victime porte le pseudo de l'attaquant, validé.** En prime, une ligne `content_reports` `hate_speech / actioned` est créée avec la victime en `reporter_id` *et* `target_user_id` — elle remonte comme récidiviste dans la file admin. Les UUID sont récupérables : `profiles` est en SELECT ouvert à `anon` pour les profils non privés.

**Fix** : reprendre le garde de `moderate-comment/index.ts:36-52` (`isServiceRole(req)` en temps constant) avant toute lecture du body, et déclarer la fonction dans `config.toml` avec `verify_jwt = false`.

---

### 3. `moderate-avatar` : même IDOR

**Où** : `supabase/functions/moderate-avatar/index.ts:141`

Garde identique (présence du header seule), `user_id` et `avatar_url` viennent du body. Avec une URL d'image NSFW hébergée par l'attaquant : `avatar_url = null` sur le profil de la victime + `content_reports` `sexual_content / actioned` contre elle.

*Correction par rapport au premier passage* : la suppression dans le bucket ne fonctionne pas dans ce scénario (le chemin est dérivé de l'URL du body), et forcer `approved` sur son propre avatar n'a aucun effet — `avatar_moderation_status` n'est lu nulle part côté client. L'impact réel est donc : **effacement d'avatar de tiers + pollution de la file de modération**.

**Fix** : identique au point 2.

---

### 4. `send-friend-request-email` : aucune authentification du tout

**Où** : `supabase/functions/send-friend-request-email/index.ts:16`

136 lignes, **zéro lecture du header `Authorization`**. Le handler fait `await req.json()` puis crée un client `service_role`. Aucun contrôle qu'une demande d'ami existe réellement en base.

*Correction* : ce n'est pas un « relais ouvert » — l'adresse de destination vient de `auth.admin.getUserById(recipientId)`, pas du body, et le template est figé. C'est un **déclencheur de notification non authentifié** : boucle sur `{record:{type:"friend_request", user_id:"<victime>", from_user_id:"<qui on veut>"}}` → email-bombing ciblé depuis `hello@lexday.fr`, sans rate limiting. Risque principal : réputation d'expédition du domaine (blacklist Resend/spam) + faux signal social exploitable en ingénierie sociale.

**Fix** : `timingSafeEqual` sur la service_role en tête de `serve`, + `verify_jwt = false` dans `config.toml`.

---

### 5. `update_book_metadata` existe en **deux surcharges** en prod → tout enrichissement de catalogue échoue

**Vérifié en base** :
```
update_book_metadata(p_book_id bigint, p_cover_url text, p_description text, p_page_count int, p_author text, p_genre text, p_google_id text)
update_book_metadata(p_book_id bigint, ..., p_google_id text, p_isbn text)
```
La migration `20260428_add_isbn_to_update_book_metadata.sql` a fait un `CREATE OR REPLACE` en ajoutant un paramètre → signature différente → seconde fonction créée, l'ancienne jamais droppée. PostgREST ne peut pas résoudre une RPC surchargée → **PGRST203 / 300 Multiple Choices** dès que le body ne correspond pas exactement à une signature.

Les deux call-sites (`books_service.dart:716` et `:1712`) sont dans un `try/catch` qui ne fait que `debugPrint` → **échec 100 % silencieux**. En pratique, l'enrichissement Google Books et la mise à jour de couverture depuis le sync Kindle ne fonctionnent que dans le cas où les 8 paramètres sont fournis. Le repo connaissait déjà le piège (`20260510000002_drop_old_feed_bundle.sql` le documente).

**Fix** :
```sql
drop function if exists public.update_book_metadata(bigint,text,text,integer,text,text,text);
-- puis vérifier : grant execute on function public.update_book_metadata(bigint,text,text,integer,text,text,text,text) to authenticated;
```

---

### 6. Session de lecture définitivement perdue si la file offline se synchronise pendant la session

**Où** : `lib/services/offline_session_queue.dart:153-201` + `lib/services/reading_session_service.dart:385-393`

`_syncStarts()` pousse en base **tous** les démarrages en attente, y compris celui d'une session **encore en cours**, retire l'entrée de `_startKey`, et le mapping `temp_id → real_id` est une variable **locale** (`idMapping`, l.161) qui n'est appliquée qu'aux fins déjà en file et n'est jamais persistée. Quand l'utilisateur termine ensuite : `flushStartAndGetRealId()` renvoie `null` (entrée absente) → `queueOfflineEnd()` remet une fin avec un `session_id` en `offline_…` → `_syncEnds` fait `if (sessionId.startsWith('offline_')) continue;` → **bloquée à vie**.

**Repro** : démarrer une session sans réseau (métro, avion) → l'app passe en arrière-plan → retour au premier plan avec le réseau (`ConnectivityProvider._refreshAndSync → syncAll`) → terminer la session depuis la page ouverte.

**Conséquences** : durée et pages perdues, ligne `reading_sessions` restée ouverte en base → **bannière « en train de lire » permanente et FAB bloqué**, alors que l'écran de résumé s'affiche normalement (l'utilisateur croit que c'est enregistré). Corollaire : le chemin « J'ai terminé le livre » appelle `endSession` sans `activeSession` → `throw Exception('Session hors ligne introuvable.')`, impossible de finir le livre.

*Trace en prod* : 2 sessions ouvertes depuis plus de 2 jours sur 2 utilisateurs différents (sur 48 comptes). Cohérent avec ce scénario.

**Fix** : persister le mapping `temp_id → real_id` dans SharedPreferences, le consulter dans `flushStartAndGetRealId` **et** dans `_syncEnds` avant le skip. (Patch détaillé disponible.)

---

## 🟠 Majeurs

### 7. Splash bloqué indéfiniment si une init échoue — et jusqu'à 24 s d'attente sinon

**Où** : `lib/pages/splash/splash_screen.dart:101` (appel), `:135-146`

`_initializeAndNavigate()` est lancé sans `await`, sans `.catchError`, sans `try` global. Le `throw StateError` volontaire (env manquant) et `await Supabase.initialize(...)` sont **hors** de `_bestEffort`. Il n'y a ni `runZonedGuarded`, ni `FlutterError.onError`, ni `ErrorWidget.builder` dans tout `lib/` (vérifié). L'exception part dans un Future non écouté → **le `Navigator.pushReplacement` n'est jamais atteint** : logo animé figé pour toujours, aucun message, aucun retry, et c'est déterministe au relancement. C'est exactement l'incident AAB 1.0.5+11 que le commentaire du fichier évoque — la protection n'a pas été posée.

Second point confirmé : les 4 `_bestEffort` sont **séquentiels** avec un timeout de 6 s chacun → **24 s de splash** sur un Wi-Fi « connecté sans internet » (PostHog et RevenueCat font du réseau).

**Fix** : `.catchError` sur l'appel avec un écran d'erreur + bouton Réessayer, et `Future.wait([...])` pour les 4 inits non critiques (plafond ramené à 6 s).

---

### 8. Toutes les couvertures cassées dans la bibliothèque d'un club

**Où** : `lib/pages/groups/group_list_detail_page.dart:261` → `lib/widgets/cached_book_cover.dart:1099`

La tuile passe `width: double.infinity`, et le widget fait `memCacheWidth: (widget.width * dpr).toInt()` → `UnsupportedError: Infinity or NaN toInt` **pendant le build** → chaque couverture est remplacée par un `ErrorWidget` (bloc rouge en debug, bloc uni en release), exception re-levée à chaque scroll.

La preuve que le bug est connu : `user_books_page.dart:977` fait déjà `width: width.isFinite ? width : 140`. Le correctif n'a jamais été reporté. Vérification exhaustive des ~55 appelants : **c'est le seul non gardé** (`friend_profile_page.dart:1312` utilise `constraints.maxWidth` dans une `GridView`, donc fini).

**Fix** (à faire dans le widget pour blinder tous les appelants) :
```dart
memCacheWidth: widget.width.isFinite ? (widget.width * dpr).toInt() : null,
memCacheHeight: widget.height.isFinite ? (widget.height * dpr).toInt() : null,
```

---

### 9. Kindle : les streaks ne sont jamais synchronisées sur une bibliothèque moyenne, et le blocage est auto-entretenu

**Où** : `lib/widgets/kindle_auto_sync_widget.dart:35`, `:62`, `:177`

Le timeout global de 60 s est armé dès `initState` et couvre tout le pipeline. Budget avant l'import : ~19-25 s de fixes (attentes + scrolls) ; `importKindleBooks` fait ≥ 2 aller-retours Supabase par livre + jusqu'à 3 appels Google Books → dépassement quasi certain au-delà de ~20-30 livres. Au timeout, `_finish()` → `onCompleted` → widget démonté → `_disposed = true` → **`_extractStreaks` n'est jamais exécuté**.

Pire : `saveLocally(tempData)` est appelé **à mi-parcours** (l.177) avec un `KindleReadingData` dont tous les champs streak sont `null` → écrase le cache **et** met `kindle_last_sync = now`, ce qui bloque toute nouvelle tentative pendant 24 h (`kindle_auto_sync_service.dart:34-45`). La feature reste durablement cassée, silencieusement.

**Fix** : ne pas persister à mi-parcours (ou fusionner avec `loadFromCache()`), dissocier `kindle_last_sync` (dernier sync **réussi**) de l'écriture du cache, et remplacer le timeout global par des timeouts par étape.

---

### 10. Auto-pause de 4 h jamais finalisée → tout le temps lu ensuite est retranché

**Où** : `lib/navigation/main_navigation.dart:327-337` et `:389-395`

Au retour au premier plan après ≥ 4 h, le code fait `savePauseStart(backgroundedAt)` — une pause **antidatée et non bornée**. `finalizeCurrentPause()` n'a qu'un seul appelant dans tout `lib/` : `resumeSession`, déclenché uniquement par le bouton play de la page active, la Live Activity ou la Watch. Le bouton « Continuer » de la modale ne fait qu'un `Navigator.pop`.

Comme `getTotalPauseDuration()` inclut la pause ouverte, `adjustedEnd` reste figé à l'instant du passage en arrière-plan : **la durée enregistrée s'arrête là**. Si le cumul dépasse le temps écoulé, `end_time < start_time` (aucune contrainte `CHECK` en base).

*Atténuation* : si l'utilisateur ouvre la page de session active et appuie sur play, tout se répare. Le bug se matérialise s'il clique « Continuer », lit, puis termine directement depuis la bannière.

**Fix** : faire appeler `resumeSession(...)` par le bouton « Continuer ».

---

### 11. L'e-mail de tous les profils publics est lisible avec la clé anon — **vérifié en prod**

La policy `Anon can view public profiles` autorise `anon` en SELECT sur `profiles` sans restriction de colonne, et `profiles.email` est renseigné pour **48 profils sur 48**, tous non privés.

Un `GET /rest/v1/profiles?select=display_name,email` avec la clé anon (extraite du binaire) renvoie l'annuaire complet des utilisateurs. Enjeu RGPD, et matière première pour le phishing.

**Fix** : restreindre la policy anon à une vue exposant uniquement les colonnes publiques (`id, display_name, avatar_url`), ou `REVOKE SELECT (email, email_hash, phone, phone_hash, fcm_token, notion_access_token) ON profiles FROM anon, authenticated`. À noter : `authenticated` a aussi `SELECT` sur `true` pour toute la table.

---

### 12. `DEV_FORCE_PREMIUM` vaut `"true"` dans le template et n'a aucune garde release

**Où** : `env.example.json:9`, `lib/config/env.dart:52`, `lib/services/subscription_service.dart:80`

`bool.fromEnvironment('DEV_FORCE_PREMIUM')` n'est jamais croisé avec `kReleaseMode` (`grep kReleaseMode lib/` → 0 résultat). Un `env.json` dérivé du template livre une build de prod où **tout le monde est premium côté client et RevenueCat n'est même pas initialisé** — donc aucun achat observé, aucun webhook, aucun revenu. Silencieux.

**Fix** : `"DEV_FORCE_PREMIUM": "false"` dans le template, et
```dart
static const devForcePremium = kReleaseMode ? false : bool.fromEnvironment('DEV_FORCE_PREMIUM');
```

---

### 13. Pagination du feed définitivement morte + spinner permanent

**Où** : `lib/pages/feed/feed_page.dart:358-362`

```dart
setState(() => _isLoadingMore = true);
try {
  final user = supabase.auth.currentUser;
  if (user == null) return;   // ← sort sans jamais remettre le flag, pas de finally
```
`_onScroll` teste `!_isLoadingMore` → plus aucun chargement, et le `CircularProgressIndicator` de bas de liste reste affiché en permanence. `FeedPage` vivant dans un `IndexedStack`, **l'état survit aux changements d'onglet jusqu'au redémarrage de l'app**. Déclencheur : session expirée ou course au sign-out.

**Fix** : `finally { if (mounted) setState(() => _isLoadingMore = false); }`.

---

### 14. Le suivi social contourne les blocages dans le fallback « Découvrir des lecteurs »

**Où** : `lib/services/feed_social_loader.dart:152-158`

Quand PYMK + `get_suggested_readers` remontent moins de 5 suggestions, le code interroge `profiles` en direct sans aucun `NOT EXISTS` sur `user_blocks` — alors que toutes les RPC équivalentes filtrent les blocages côté serveur depuis `20260524000001`. Résultat : **une personne bloquée peut réapparaître dans les suggestions**, avec un bouton « Ajouter ». Sensible (c'est typiquement du harcèlement).

**Fix** : router ce fallback par une RPC `SECURITY DEFINER` appliquant le même filtre.

---

### 15. Trois features payantes ne sont gardées que côté client — **vérifié en base**

- **Emojis premium** : `CHECK (emoji = ANY (ARRAY['❤️','📚','🔥','🌟','😭']))` autorise les 5 emojis pour tout le monde ; la policy INSERT ne vérifie que `auth.uid() = user_id`. Le seul contrôle est un `if` dans le widget.
- **Listes personnalisées** : aucun trigger sur `user_custom_lists` (vérifié : `none`), plafond de 5 en Dart uniquement.
- **Clubs de lecture** : `_enforceGroupLimit()`, même schéma.

Un client HTTP ou un APK modifié contourne les trois.

**Fix** : triggers `BEFORE INSERT` comparant `COUNT(*)` au plafond sauf premium, et une policy INSERT sur `activity_reactions` du type `WITH CHECK (auth.uid() = user_id AND (emoji = '❤️' OR is_user_premium(auth.uid())))`.

---

## 🟡 Moyens

### 16. Kindle : des livres passent en « terminé » à tort, sans le flag d'exclusion

**Où** : `lib/services/kindle_webview_service.dart:240-254` + `lib/services/books_service.dart:735-792`

L'`extractionScript` de la page Reading Insights balaie **tout le document** (`a[href*="/dp/"], a[href*="/gp/product/"], a[href*="/B0"]`) et force `percentComplete: 100` — que `markBooksAsFinished` ne lit d'ailleurs jamais. Le match se fait en `ilike('title','%…%').limit(1)` **sans `order`** (non déterministe entre éditions/omnibus), et l'update écrit `{'status':'finished'}` **sans `kindle_auto_finished: true`**, contrairement à `importKindleBooks`. Or `20260313_fix_kindle_books_excluded_from_badges.sql` n'exclut des badges que les lignes `kindle_auto_finished = TRUE` → **badges et compteur de livres terminés faussés**.

*Correction du premier passage* : le scénario « carrousel de recommandations » ne tient pas — l'update exige une ligne `user_books` préexistante. Le vrai vecteur : l'auto-sync importe d'abord toute la bibliothèque en `to_read`, puis n'importe quel lien `/dp/` de la page Insights (tuiles « en cours », blocs promo, hors section « titles read ») flippe le livre en `finished`.

À noter : le script correctement scopé existe déjà dans le fichier (`extractBooksScript`, l.829-867 — remontée depuis `/^\d+\s*titles?\s*read$/i`) mais c'est du **code mort**, référencé nulle part.

**Fix** : réutiliser ce scoping ; requête `user_books` jointe à `books` filtrée sur `user_id` avec `.order('id')` ; poser `kindle_auto_finished: true` sur toute bascule non issue d'une session de lecture.

### 17. Session fantôme quand on démarre ET termine hors ligne

`queueEndSession` ne touche pas `_startKey`, et `getAllOfflineActiveSessions()` ne croise pas les fins en attente → bannière « en train de lire » persistante, FAB qui refuse une nouvelle session, dialogue sur une session déjà terminée. **Aucune donnée perdue** dans le cas nominal (la sync répare tout) — sauf si l'utilisateur clique « Annuler » sur le fantôme : `removeOfflineStartSession` ne purge que `_startKey` et la fin en attente devient orpheline à vie.
**Fix** : filtrer les `temp_id` présents dans `_endKey`, et purger les deux clés à l'annulation.

### 18. Le quota gratuit du chat IA se remet à zéro en supprimant ses conversations

`ai-chat/index.ts:512-544` compte les messages **via la liste des `ai_conversations` de l'utilisateur** ; si elle est vide, tout le bloc de plafonnement est sauté. L'utilisateur a bien la policy DELETE, le `ON DELETE CASCADE` efface les messages, et le bouton existe dans l'UI (3 taps). `get_ai_monthly_message_count()` a exactement la même faille. Le quota « cadeau » du même fichier, lui, est correct : il passe par `ai_usage`, table sans policy DELETE (vérifié en prod : `aucune`).
**Fix** : compter dans `ai_usage` avec `feature = 'chat'`.

### 19. `deleteComment` / `updateComment` renvoient `true` même quand la RLS bloque

`lib/services/comments_service.dart:151-186` : un UPDATE/DELETE PostgREST filtré par RLS qui ne matche aucune ligne renvoie **204**, pas une erreur. Le code ne demande pas `.select()` → l'UI retire le commentaire, qui réapparaît au prochain refresh.
**Fix** : chaîner `.select('id')` et retourner `(res as List).isNotEmpty`.

### 20. « Déconnecter Kindle » ne supprime rien côté serveur — **vérifié en prod**

`kindle_sync` a des policies `SELECT`, `INSERT`, `UPDATE` — **aucune `DELETE`**. Le `.delete().eq('user_id', …)` de `kindle_webview_service.dart:1063` supprime 0 ligne sans erreur. Les streaks et `books_data` (titres lus) restent en base indéfiniment après une déconnexion confirmée à l'utilisateur. Enjeu RGPD.
**Fix** : ajouter la policy DELETE + vérifier le nombre de lignes supprimées côté client.

### 21. Le matching de contacts par téléphone ne peut structurellement rien matcher

`profiles.phone_hash` n'est **jamais alimenté** : le trigger `trg_hash_profile_email` ne gère que l'e-mail, le backfill de `20260323` est un no-op (`WHERE phone IS NOT NULL AND phone_hash IS NOT NULL`), et aucune écriture client. `find_contacts_matches_v2` compare `p.phone_hash = ANY(...)` → branche morte. Conséquence : l'app **envoie jusqu'à plusieurs milliers de numéros du carnet d'adresses par batchs de 500 pour rien**. Sensible côté vie privée.
**Fix** : trigger de hachage sur `phone` + backfill, ou cesser d'envoyer `p_phones`. Au passage, la RPC renvoie `p.email` des profils matchés — à retirer.

### 22. `insertPastSession` tronque la durée saisie autour de minuit

`reading_session_service.dart:742-745` : `effectiveStart` est ramené à minuit sans avertir. Saisir « fin 00:30, durée 90 min » enregistre **30 min**. Cas plus grave : « fin 00:01, durée 60 min » → 1 min < seuil de 2 min de `FlowService` → **la lecture ne compte pas pour la flamme**.
**Fix** : laisser `start_time` déborder sur la veille (la flamme n'utilise que `end_time`), ou avertir dans l'UI.

### 23. Boutons Pause/Reprendre de la Live Activity inertes après un relaunch

`live_activity_service.dart:26` affirme que les commandes sont poussées par l'AppDelegate ; or `grep invokeMethod ios/Runner/*.swift` ne donne **aucun** appel. Le seul chemin réel est le `Timer.periodic` de `startCommandPolling`, branché uniquement au démarrage d'une session. Après un kill de l'app, une pause depuis l'écran verrouillé n'écrit jamais `session_paused_at` → **le temps de pause est compté comme de la lecture**.
**Fix** : ré-armer `startCommandPolling` au lancement quand une session est active (comme le fait déjà `WatchControlService.start()`).

### 24. Auto-sync Kindle *flaky* sur Android

`onWebResourceError: (_) => _finish()` (`kindle_auto_sync_widget.dart:57`) n'utilise pas `isForMainFrame`. Sur Android, `onReceivedError` remonte aussi les **sous-ressources** : une pub, un tracker ou une image bloquée sur une page Amazon suffit à annuler le sync. (Pas de faux positif sur iOS : WKWebView ne remonte que la frame principale.) L'échec est indiscernable d'un succès côté appelant.
**Fix** : `onWebResourceError: (e) { if (e.isForMainFrame ?? true) _finish(); }` + log de l'erreur.

### 25. Cookies expirés : `read.amazon.com/landing` traité comme une bibliothèque authentifiée

`kindle_auto_sync_widget.dart:82/92` ne teste que `/ap/signin` et `/ap/register`, alors que `kindle_login_page.dart:133-146` documente qu'Amazon redirige les non-authentifiés vers `/landing`. `_waitForLibraryLoaded()` est décoratif (son retour n'est que loggé, et le script renvoie `loaded: true` dès `bodyLength > 1000`).
*Correction* : l'expiration **finit** par être détectée à l'étape Insights — la claim « non détecté » était excessive. Dégât résiduel : passe d'extraction inutile, risque de pollution de bibliothèque, et blocage 24 h si un pseudo-livre déclenche `saveLocally`.
**Fix** : ajouter `|| url.contains('/landing')` et exploiter réellement le retour de `_waitForLibraryLoaded()`.

### 26. Fiche livre d'un ami : un échec réseau s'affiche comme « 0 session, 0 page, 0 min »

`friend_book_detail_page.dart:72-103` : le `catch` ne fait qu'un `debugPrint`, aucun champ d'erreur, aucun retry (`_load()` n'est appelé que dans `initState`). En mode avion, la page s'affiche avec le titre en cache et des zéros — indiscernable de « cet ami n'a jamais lu ce livre ».
**Fix** : `String? _error` + bloc erreur avec bouton Réessayer.

### 27. « Ajouter une lecture passée » sur un livre hors bibliothèque crée une session orpheline

`user_books_page.dart:1373` : `_startReadingSession` a reçu le rattrapage « ajouter en `reading` », pas `_addPastSession`. Depuis le feed, la session est créée et publiée mais le livre n'apparaît nulle part dans la bibliothèque, et les actions masquer/supprimer restent cachées.
**Fix** : même rattrapage, ou mieux, déplacer l'ajout auto dans `insertPastSession` côté service.

### 28. Cache des tendances : fuite entre comptes et mémorisation des résultats vides

`trending_books_service.dart:85-113` : `static _cache` avec TTL 30 min, **non purgé au logout** (le flux de déconnexion purge `TrendingService`, `GoogleBooksService`, `AvatarCacheService`, `FeedCacheService` — pas celui-ci) alors que la RPC est personnalisée (elle exclut les livres de `user_books` de l'appelant). Un compte B qui se connecte dans les 30 min voit les tendances calculées pour A. Par ailleurs le cache n'est pas indexé sur `limit` et mémorise les listes vides 30 min.
**Fix** : `clearCache()` appelé aux deux points de logout, ne cacher que si `isNotEmpty`, indexer sur `limit`.

### 29. N+1 sur le feed

`book_finished_card.dart:234-239` interroge `books` dès que `payload['book_id']` existe, sans regarder `payload['book_title']` / `book_cover` — alors que les migrations `20260401` et `20260429` enrichissent justement le payload pour éviter ce round-trip. 15 activités = 15 requêtes séquentielles, relancées à chaque recyclage de carte au scroll.
**Fix** : la garde existe déjà dans `friend_activity_card.dart:107`, l'appliquer ici.

### 30. `getReaderCounts` : compteurs faux ou plafonnés

`curated_lists_service.dart:80-99` interroge `user_saved_curated_lists` sans `.eq('user_id', …)` ni `.limit()`, et compte côté Dart. Selon la RLS : soit tous les compteurs valent 0/1, soit le client télécharge tout et le `max-rows` PostgREST (1000) tronque silencieusement.
**Fix** : réutiliser `curated_reader_counts` déjà renvoyé par `get_feed_bundle`.

### 31. Aucune contrainte d'unicité sur les sessions ouvertes

`getActiveSession()` termine par `.maybeSingle()`, qui **jette** avec 2 lignes ouvertes ; le seul garde-fou est côté client et fail-open. En base, `idx_reading_sessions_active` existe mais n'est **pas unique**. Aucun doublon en prod aujourd'hui (`0`), donc c'est de la robustesse, pas un incident en cours.
**Fix** : `CREATE UNIQUE INDEX ... ON reading_sessions(user_id, book_id) WHERE end_page IS NULL;` + `.order('start_time', ascending: false).limit(1)` côté client.

---

## 🔵 Mineurs

- **Widget iOS, minutes du jour** : `widget_service.dart:183` filtre sur `start_time >= todayStart` alors que la flamme attribue le jour d'après `end_time`. Une lecture 23h40→00h40 n'est comptée dans aucun jour côté widget.
- **~15 chaînes françaises en dur** dans `user_books_page.dart` (2063, 2089, 2121, 2231, 2244, 2251, 2436, 2560, 2623, 2682, 2697, 2772, 2897, 2985) : « Session de lecture », « Commencer une lecture », « Statistiques de lecture », « Ma Fiche de Lecture »… La fiche livre reste partiellement en français en EN/ES. Bonne nouvelle : les 3 `.arb` sont parfaitement synchronisés (1250 clés chacun, zéro écart) et aucune clé utilisée n'est manquante. 3 chaînes en dur aussi dans `onboarding/widgets/step_sync_progress.dart`.
- **`friend_book_detail_page.dart:197`** : seule page nouvelle sans `ConstrainedContent` → s'étale sur toute la largeur sur iPad.
- **`choose_display_name_sheet.dart:100-104`** : `if (user == null) return;` après `_saving = true`, sans `finally` → spinner définitif et les deux boutons morts si la session a expiré.
- **Sessions d'un ami sans barre de progression** : `get_friend_books` / `get_friend_profile_v2` ne sélectionnent pas `b.page_count`, donc `pageCount` est toujours `null` dans `friend_book_detail_page.dart:58`.
- **Insights premium d'un ami visibles par un compte gratuit** (`session_detail_page.dart:991-1001`) : `showInClear = true` dès que le *propriétaire* est premium, sans regarder le statut du lecteur — alors que les mêmes métriques sont floutées sur ses propres sessions. À arbitrer (intentionnel ou non).
- **Statuts annoncés ≠ statuts importés** dans la page de validation Kindle dès qu'on décoche un livre (indices recalculés sur la liste filtrée).
- **Token FCM imprimé en clair en release** (`push_notification_service.dart:125`) — `print` n'est pas supprimé en release.
- **Comparaisons de secrets non timing-safe** dans 6 fonctions cron (`send-push-notification`, `send-streak-reminders`, `send-wrapped-notification`, `send-reengagement`, `refresh-covers`, `sync-literary-prizes`) alors que le helper existe déjà ailleurs.
- **`extract-book-from-cover` sans quota** : authentification réelle (contrairement aux 3 fonctions ci-dessus) mais aucun plafond. Coût d'abus faible (~0,0002 $/appel en gpt-4o-mini, entrée bornée à 3000 car., sortie à 120 tokens) — c'est une dette de rate limiting, pas une vulnérabilité. Le `ai_usage` est déjà écrit, il suffit de le relire.
- **`generate-reading-sheet`** : `force: true` court-circuite le cache sans aucun plafond, pour un premium.
- **Caches statiques non bornés** dans `cached_book_cover.dart` (6 `Map` jamais purgées) — croissance monotone sur une longue session de scroll.
- **Drift repo ↔ prod** : 6 RPC appelées par le client n'ont aucun `CREATE FUNCTION` dans les 161 migrations (`get_friend_profile_v2`, `get_friend_book_detail`, `count_completed_books`, `get_friends`, `remove_friend`, `check_duplicate_book_by_title_author`). Elles **existent bien en prod avec les bons GRANT** (vérifié), donc rien n'est cassé — mais un `supabase db reset` sur une base neuve casserait la page profil ami. À rattraper par un `pg_dump` dans une migration.
- **`endSession` détruit l'état de pause avant l'écriture DB** (`reading_session_service.dart:399-405`) : le chemin fréquent (erreur réseau) est correctement rattrapé par la mise en file offline avec `adjustedEnd` calculé avant. Ne casse que sur une erreur **non réseau** suivie d'un retry → durée gonflée du cumul de pause. Combinaison peu probable.

---

## Ce qui a été vérifié et qui est **correct** (faux positifs écartés)

- **`friend_activity_view`** : la vue est bien en `security_invoker=on` en prod (vérifié) — l'alerte du premier passage était fausse. Toutes les vues du projet sont en `security_invoker`.
- **Vérification `is_premium` côté serveur** : présente et **avant** tout appel OpenAI dans les 7 Edge Functions premium, y compris le tour d'outil « cadeau » de `ai-chat`.
- **`revenuecat-webhook`** : `verify_jwt = false` documenté + comparaison à temps constant avant tout parsing.
- **`grant-referral-reward` / `apply-referral`** : filleul dérivé du JWT, fenêtre de 30 jours, contrainte d'unicité, service_role exigée en timing-safe.
- **Aucun secret en dur côté client** : `env.dart` passe tout par `String.fromEnvironment`, aucune clé `sk-…` ni service_role dans `lib/`, `web/`, `assets/`.
- **RPC `SECURITY DEFINER` amis** correctement gardées depuis `20260713_fix_private_profile_anon_gate.sql` ; la fuite de `p.email` de `get_user_search_data` a bien été retirée.
- **`sync_client_premium_status`** supprimée et table `subscriptions` verrouillée — c'est bien `profiles.is_premium` qui est resté ouvert (point 1).
- **Écritures directes sur `books`** : toutes limitées aux colonnes couvertes par le GRANT de `20260722` — aucun 42501 latent.
- **`reading_sessions.book_id` est bien `TEXT`**, timestamps en `timestamptz`, `.toLocal()`/`.toUtc()` corrects.
- **Disposal des contrôleurs** : scan exhaustif `AnimationController` / `TextEditingController` / `ScrollController` / `PageController` / `Timer` / `FocusNode` → **aucune fuite**. `addListener`/`removeListener` appariés partout.
- **`connectivity_provider`, `feed_prefetcher`, `feed_social_loader`** (hors point 14) : propres, gardés, avec fallback.
- **Lecture d'annotation audio** : le listener `playerStateStream` vérifie bien `mounted` et la subscription se ferme avec le player — pas de fuite. Le vrai défaut est l'absence de `try/catch` autour de `setUrl`/`play` : **le bouton play reste muet** en cas d'erreur réseau, sans message.
- **`setState` après dispose** dans `start_reading_session_page_unified` (OCR) et `user_books_page._loadSessionData` : réels mais **sans impact visible** (exception loggée, State déjà mort). À corriger pour la propreté des logs, pas en urgence.
- **Advisors Supabase** : 0 alerte de niveau ERROR. Les 93 WARN `authenticated_security_definer_function_executable` et 64 `function_search_path_mutable` sont du bruit structurel, à traiter à froid.

---

## Ordre de traitement suggéré

1. **Aujourd'hui** — points 1 à 5 : le `GRANT` sur `is_premium`, les 3 Edge Functions non authentifiées, le `DROP FUNCTION` de la surcharge. Ce sont 5 correctifs serveur, sans release client, déployables dans l'heure.
2. **Prochaine release client** — points 6 à 10 : perte de session offline, splash, couvertures de club, timeout Kindle, auto-pause 4 h.
3. **Ensuite** — 11 à 15 (exposition des e-mails, `DEV_FORCE_PREMIUM`, pagination du feed, blocages, gating premium serveur).
4. **À froid** — le reste, en commençant par ce qui touche aux données (16, 20, 21, 22).

Les points 1, 2, 3, 4, 5, 11, 15, 20 et 31 ont été vérifiés directement contre la base de production ; les autres le sont contre le code exact de ton dossier de travail.

# Sync Kobo — spec d'implémentation (calée sur l'existant Kindle)

Date : 13/09/2026. Objectif : reproduire pour Kobo (Fnac) ce que fait le sync Kindle —
livre en cours, sessions datées, jours lus pour la flamme — en réutilisant au maximum
`books_service.dart`, `reading_session_service.dart`, le workmanager et la table
`kindle_read_days` (généralisée).

## 0. Ce que donne l'API Kobo (vérifié dans kobodl + calibre-web)

- **Activation** (une fois) : `GET https://auth.kobobooks.com/ActivateOnWeb` → HTML contenant
  un code (`%26code%3D(\d+)`) et un `data-poll-endpoint`. L'utilisateur va sur
  `https://www.kobo.com/activate` (WebView in-app), se connecte, saisit le code. L'app
  poll l'endpoint jusqu'à `Status == "Complete"` → `UserKey`.
- **Device auth** : `POST https://storeapi.kobo.com/v1/auth/device` avec `DeviceId` (hex 64),
  `SerialNumber` (hex 32), `UserKey`, `AffiliateName`, `AppVersion`, `PlatformId`, `ClientKey`
  → `AccessToken`, `RefreshToken`. Refresh : `POST /v1/auth/refresh`.
- **Init** : `GET /v1/initialization` (Bearer) → `Resources` (dont `library_sync`).
- **Sync** : `GET {library_sync}` avec `x-kobo-synctoken` (renvoyé en header, à persister ;
  `x-kobo-sync: continue` → repaginer). Entrées :
  `NewEntitlement` / `ChangedEntitlement` (`BookMetadata`: Title, Contributors, ISBN,
  RevisionId, CoverImageId…) et `ChangedReadingState.ReadingState` :
  - `EntitlementId`
  - `CurrentBookmark.ProgressPercent` (0-100), `LastModified`
  - `Statistics.SpentReadingMinutes`, `RemainingTimeMinutes`, `LastModified`  ← temps RÉEL
  - `StatusInfo.Status` (`ReadyToRead|Reading|Finished`), `TimesStartedReading`,
    `LastTimeStartedReading`, `LastTimeFinished`
- Limites : seuls les livres du cloud Kobo (achat Kobo, OverDrive/bibliothèque) ; les epub
  sideloadés USB n'y sont pas. API privée des liseuses : même zone grise que Kindle.
- Delta vs Kindle : (+) temps de lecture réel → sessions à durée VRAIE, pas estimée ;
  (+) un seul appel réseau (pas de HTML par livre) ; (−) pas de `days_read` global →
  les jours lus se déduisent des `LastModified` observés à chaque sync.

## 1. Modèle de données (une migration `20260914_kobo_sync.sql`)

Généraliser plutôt que dupliquer :

- `user_books` : `kobo_entitlement_id TEXT`, `kobo_percent SMALLINT`, `kobo_progress_at
  TIMESTAMPTZ`, `kobo_spent_minutes INT` (cumul Kobo au dernier sync, pour les deltas).
  (Garder les colonnes `kindle_*` telles quelles — pas de refacto risquée.)
- `reading_sessions.source` : accepter `'kobo'`. Vérifier le CHECK éventuel
  (`20260326_text_check_constraints.sql`) et l'exemption flamme dans
  `get_user_streak_stats` : `rs.source NOT IN ('kindle','kobo')` au lieu de
  `IS DISTINCT FROM 'kindle'`.
- `kindle_read_days` → ajouter `source TEXT NOT NULL DEFAULT 'kindle'`, PK
  `(user_id, day, source)`. Renommer en `ereader_read_days` + vue `kindle_read_days`
  optionnelle ; sinon garder le nom et documenter. `get_user_streak_stats` et
  `send-streak-reminders` ne filtrent pas par source → aucun changement si on garde le nom.
- `books.source` : `'kobo'` (dédup `importKindleBooks` par titre+source → mieux :
  résoudre par ISBN quand `BookMetadata.ISBN` est fourni, puis titre).
- `profiles` ou prefs : la connexion Kobo est locale (tokens dans flutter_secure_storage,
  pas en base). Prefs `kobo_*` miroir des `kindle_*`.

## 2. Dart — nouveaux fichiers (miroir des fichiers Kindle)

| Kindle | Kobo | Contenu |
|---|---|---|
| `kindle_cookie_store.dart` | `kobo_auth_store.dart` | `DeviceId`, `SerialNumber`, `UserKey`, `AccessToken`, `RefreshToken`, `syncToken` dans `flutter_secure_storage`. `refreshIfNeeded()` (401 → `/v1/auth/refresh`). `clear()`. |
| `kindle_login_page.dart` + `kindle_connect_sheet.dart` | `kobo_connect_page.dart` | 1) `GET ActivateOnWeb` → code ; 2) affiche le code + WebView `kobo.com/activate` ; 3) poll toutes les 3 s (timeout 5 min) ; 4) `/v1/auth/device` ; 5) premier sync complet. `ConstrainedContent`, l10n fr/en/es. |
| `kindle_http_sync.dart` | `kobo_http_sync.dart` | `KoboHttpSync(auth).run()` : init (cache `library_sync` URL) → sync paginé avec synctoken → `List<KoboBookProgress>` (title, author, isbn, coverUrl, entitlementId, percent, spentMinutes, status, lastModified, lastTimeFinished). Pur HTTP, timeout 8 s, utilisable en arrière-plan. |
| `kindle_auto_sync_service.dart` | `kobo_auto_sync_service.dart` | mêmes cadences : progress 1 h, backoff échecs, `isKoboConnected()`, `isAutoSyncEnabled()`. |
| `kindle_background_sync.dart` | généraliser : `ereader_background_sync.dart` | UN seul dispatcher/task id `fr.lexday.app.kindleProgress` (déjà dans Info.plist — ne pas ajouter d'identifiant) qui enchaîne Kindle puis Kobo si connectés. Notif id 90211 canal `kindle_sync` réutilisé. |
| `books_service.importKindleBooks` | `importKoboBooks(List<KoboBookProgress>)` | voir §3. |

Modèle : `Book.source == 'kobo'`, `ReadingSession.sourceKobo = 'kobo'`,
`isFromEreader => isFromKindle || isFromKobo` ; `isBackdated` false si `isFromEreader`.
`Feature.koboSync` dans `feature_flags.dart` (premium comme Kindle).

## 3. `importKoboBooks` — règles

Pour chaque livre (du plus ancien `LastModified` au plus récent, comme `.reversed` Kindle) :

1. Résolution : `user_books.kobo_entitlement_id` → sinon `books.isbn` → sinon
   `importKindleBooks`-like (titre nettoyé + Google Books, `source:'kobo'`).
2. Baseline : premier % connu → écrire `kobo_percent/at/spent_minutes`, pas de session.
3. Delta % > 0 ET `page_count` connu → session `source:'kobo'` :
   - pages = round(Δ% × page_count), ≥ 1 ;
   - **durée = Δ `SpentReadingMinutes`** si > 0 (borne 1 min–6 h), sinon
     `estimateDurationForPages` (repli identique à Kindle) ;
   - `endTime = CurrentBookmark.LastModified` (vrai instant, mieux que le 21:00 Kindle) ;
   - `insertPastSession(source:'kobo', endTime)`.
4. `StatusInfo.Status == 'Finished'` ou % == 100 → statut `finished`, `kindle_auto_finished`
   style (colonne à généraliser ou nouvelle `kobo_auto_finished`).
5. Jours lus : `upsertReadDays([LastModified.date], source:'kobo')` pour chaque delta
   observé (+ `LastTimeStartedReading`, `LastTimeFinished`). Moins complet que le calendrier
   Amazon (on ne voit que les sessions entre deux syncs), d'où l'intérêt du sync 1 h
   en arrière-plan.
6. `getCurrentReadingBook` : `_kindleCurrentCandidate` → `_ereaderCurrentCandidate` qui
   prend le max(`kindle_progress_at`, `kobo_progress_at`) ; `kindlePageFromRow` généralisé.
7. `getKindleCurrentPage` → `getEreaderCurrentPage` = max des deux %.

## 4. UI

- Settings : section « Liseuses » avec Kindle (existant) + Kobo (Connecter / Dernier sync /
  Sync auto / Déconnecter), même composant que `kindle_auto_sync_widget` paramétré.
- Onboarding `step_kindle_connect` → « Connecter ma liseuse » : deux boutons Kindle / Kobo.
- Feed : `_KindleSourceBadge` → `_SourceBadge(source)` avec l10n `sessionSourceKobo`.
- Upgrade page : mentionner Kobo dans l'argumentaire premium.

## 5. Ordre de livraison

1. Migration SQL (§1) — appliquer via MCP Supabase, puis `send-streak-reminders` inchangée
   si on garde `kindle_read_days`.
2. `kobo_auth_store` + `kobo_http_sync` + test node/dart sur un vrai compte (le mien) :
   dumper une réponse sync anonymisée dans `tool/kobo_sync_sample.json` pour les tests.
3. `kobo_connect_page` + settings.
4. `importKoboBooks` + candidat livre en cours + feed badge.
5. Arrière-plan : intégrer dans le dispatcher existant.
6. l10n ×3, `flutter analyze`, test device réel, PostHog `kobo_connected`, `kobo_sync_ok`.

## 6. Prompts Claude Code (dans l'ordre)

**P1 — API client**
> Crée `lib/services/kobo_auth_store.dart` et `lib/services/kobo_http_sync.dart` en
> suivant KOBO_SYNC_SPEC.md §0 et §2. Auth : flux ActivateOnWeb (code + poll) puis
> `/v1/auth/device`, refresh sur 401. Sync : `/v1/initialization` puis `library_sync`
> paginé avec `x-kobo-synctoken` persisté. Produis `List<KoboBookProgress>`
> (title, author, isbn, coverUrl, entitlementId, percent, spentMinutes, status,
> lastModified, lastTimeFinished). Pur `package:http`, timeouts 8 s, aucun accès
> Supabase. Ajoute des tests unitaires à partir de `tool/kobo_sync_sample.json`.

**P2 — Import**
> Dans `books_service.dart`, ajoute `importKoboBooks` en miroir de `importKindleBooks`
> selon KOBO_SYNC_SPEC.md §3 : résolution par entitlement_id puis ISBN, baseline sans
> session, session `source:'kobo'` avec durée = Δ SpentReadingMinutes (repli
> estimateDurationForPages), endTime = LastModified, jours lus via
> `upsertKindleReadDays(days, source:'kobo')`. Généralise `_kindleCurrentCandidate` en
> `_ereaderCurrentCandidate` (max des deux progress_at) et `getKindleCurrentPage`.

**P3 — UI + flags**
> Ajoute `Feature.koboSync`, `kobo_connect_page.dart` (code d'activation + WebView
> kobo.com/activate + poll), la section « Liseuses » dans settings_page.dart, le choix
> Kindle/Kobo dans `step_kindle_connect.dart`, et généralise `_KindleSourceBadge` en
> `_SourceBadge`. Toutes les chaînes dans les 3 .arb, `ConstrainedContent`, pas de const
> avec l10n.

**P4 — Arrière-plan**
> Renomme `kindle_background_sync.dart` en `ereader_background_sync.dart` sans changer
> `kKindleProgressTaskId` ni Info.plist ; `runOnce()` exécute Kindle puis Kobo selon
> `isKindleConnected()` / `isKoboConnected()`, une seule notif cumulée.

## 7. Test sans liseuse (Adrien n'a pas de compte Kobo)

1. Créer un compte gratuit sur kobo.com ; ajouter un ebook gratuit (boutique, filtre « gratuit »).
2. Lire quelques pages dans l'app Kobo Books iOS → le cloud reçoit un `ReadingState`.
3. Script `tool/kobo_dump.dart` (ou node) : activation via `kobo.com/activate` + `/v1/auth/device`,
   puis `library_sync` → sauvegarder la réponse anonymisée dans `tool/kobo_sync_sample.json`
   (base des tests unitaires de P1).
4. Avancer dans le livre, relancer le dump : vérifier que `ProgressPercent` et `LastModified`
   bougent. ⚠️ À vérifier : `Statistics.SpentReadingMinutes` est-il alimenté depuis l'app
   mobile ou seulement depuis une liseuse physique ? Si 0 → repli `estimateDurationForPages`.
5. Avant release : un ou deux bêta-testeurs avec une vraie Kobo (sondage in-app / mail aux
   inscrits) pour valider minutes réelles, statut Finished et livres OverDrive.

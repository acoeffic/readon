# Plan d'architecture — Logging & Tracking LexDay

**Stack retenue** : PostHog (product analytics + session events) + Sentry (crash, erreurs, perf, logs techniques) + un `LoggingService` interne qui orchestre les deux.

**Objectifs**
1. Savoir en temps réel ce qui se passe dans l'app (logs techniques, erreurs, latences API).
2. Savoir où chaque utilisateur clique et comment il navigue (events produit + session).
3. Faciliter le debug : pouvoir remonter du bug → user → session → séquence d'actions → stack trace.

---

## 1. Vue d'ensemble

```
                    ┌────────────────────────┐
                    │      LoggingService    │  (lib/services/logging_service.dart)
                    │   (façade unique)      │
                    └──────────┬─────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
   ┌────────────┐       ┌────────────┐      ┌──────────────┐
   │  PostHog   │       │   Sentry   │      │  debugPrint  │
   │ (events +  │       │ (erreurs + │      │  (dev only)  │
   │  people)   │       │  traces)   │      │              │
   └────────────┘       └────────────┘      └──────────────┘
```

**Pourquoi une façade ?**
- Un seul point d'appel dans le code (`LoggingService.event(...)`, `LoggingService.error(...)`).
- Permet de switcher de provider sans toucher aux 225 try/catch existants.
- Permet de désactiver proprement selon consentement RGPD.

---

## 2. Packages à ajouter

```yaml
# pubspec.yaml
dependencies:
  posthog_flutter: ^4.10.0       # Product analytics + session replay (optionnel)
  sentry_flutter: ^8.9.0         # Crash & error reporting
  logger: ^2.4.0                 # Formatage console dev
  device_info_plus: ^10.1.2      # Metadata device (modèle, OS)
  package_info_plus: ^8.1.0      # Version app (buildNumber, version)
```

---

## 3. Configuration environnement

**`env.example.json` — clés à ajouter**
```json
{
  "POSTHOG_API_KEY": "phc_xxx",
  "POSTHOG_HOST": "https://eu.i.posthog.com",
  "SENTRY_DSN": "https://xxx@xxx.ingest.sentry.io/xxx",
  "SENTRY_ENVIRONMENT": "production",
  "LOGGING_ENABLED": true
}
```

**Important** : utiliser l'instance EU de PostHog (`eu.i.posthog.com`) pour rester conforme RGPD — les données ne quittent pas l'UE.

---

## 4. Initialisation (main.dart)

Remplacer le `main()` actuel par un `main()` enveloppé dans `runZonedGuarded` qui capture **toutes** les erreurs :

```dart
Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(...);
    await LoggingService.init(); // <-- PostHog + Sentry

    // Capture des erreurs Flutter (framework)
    FlutterError.onError = (details) {
      LoggingService.captureFlutterError(details);
    };

    // Capture des erreurs natives (platform)
    PlatformDispatcher.instance.onError = (error, stack) {
      LoggingService.captureError(error, stack);
      return true;
    };

    runApp(MyApp());
  }, (error, stack) {
    LoggingService.captureError(error, stack, fatal: true);
  });
}
```

**Résultat** : aucune exception ne passe entre les mailles. Firebase Crashlytics n'est pas nécessaire — Sentry couvre crash natifs + Flutter.

---

## 5. Le `LoggingService` (façade)

**Fichier** : `lib/services/logging_service.dart`

Responsabilités :
- `init()` : initialise PostHog + Sentry après lecture de `env.json`.
- `identify(userId, traits)` : lie la session PostHog + Sentry à l'utilisateur Supabase. Appelé dans `auth_gate.dart` à la connexion.
- `reset()` : à la déconnexion, vide les identifiants.
- `event(name, properties)` : envoie un event PostHog + breadcrumb Sentry.
- `screen(name, properties)` : `$screen` PostHog (navigation).
- `error(error, stack, {extra})` : Sentry `captureException` + log console.
- `log(level, message, {extra})` : log technique (debug/info/warn) → console + Sentry breadcrumb.
- `setConsent(bool)` : active/désactive globalement selon RGPD.

**Pattern d'appel attendu** :
```dart
LoggingService.event('book_added', {
  'source': 'isbn_scan',
  'book_id': book.id,
  'genre': book.genre,
});

try {
  final res = await supabase.from('books').insert(...);
} catch (e, st) {
  LoggingService.error(e, st, extra: {'action': 'book_insert'});
}
```

---

## 6. Tracking automatique de navigation

Créer un `NavigatorObserver` dans `lib/navigation/analytics_observer.dart` :

```dart
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previous) {
    final name = route.settings.name ?? route.runtimeType.toString();
    LoggingService.screen(name);
  }
}
```

À brancher dans `MaterialApp` via `navigatorObservers: [AnalyticsObserver()]`. Capture automatiquement chaque changement d'écran sans toucher aux pages.

**Bonus recommandé** : standardiser en nommant les routes (`RouteSettings(name: 'feed')`) dans les `push` les plus importants. Une passe semi-automatique à prévoir.

---

## 7. Tracking des taps (clics)

Deux niveaux :

**Automatique (global)** : wrapper `MaterialApp` dans un `Listener` qui capture `PointerDownEvent`, mais **trop bruité** — déconseillé.

**Explicite (recommandé)** : créer un widget `TrackedButton` / helper `trackTap(name, fn)` utilisé sur les CTA importants :
```dart
TrackedButton(
  eventName: 'cta_add_book_tapped',
  onPressed: () => ...,
  child: Text('Ajouter'),
)
```

Combiné avec PostHog Session Replay (optionnel, à activer plus tard), on a une vue complète sans polluer le code.

---

## 8. Instrumentation des services Supabase/API

Créer un wrapper `lib/services/_instrumentation.dart` avec une fonction `trace<T>(name, fn)` :

```dart
Future<T> trace<T>(String op, Future<T> Function() fn, {Map? extra}) async {
  final sw = Stopwatch()..start();
  try {
    final r = await fn();
    LoggingService.log('info', '$op OK', extra: {'ms': sw.elapsedMilliseconds});
    return r;
  } catch (e, st) {
    LoggingService.error(e, st, extra: {'op': op, 'ms': sw.elapsedMilliseconds, ...?extra});
    rethrow;
  }
}
```

À appliquer progressivement sur les services critiques (`books_service`, `feed_cache_service`, `chat_service`, `subscription_service`). Cela transforme les 225 try/catch muets en signaux exploitables.

---

## 9. Taxonomie d'events (v1)

Convention : `object_action` en snake_case, verbes au passé pour l'action.

**Auth**
- `auth_signed_up` (method: email/google/apple)
- `auth_signed_in`
- `auth_signed_out`

**Livres & lecture**
- `book_added` (source: isbn_scan | manual | google_books | kindle_sync)
- `book_opened`
- `reading_session_started`
- `reading_session_ended` (duration_sec, pages)
- `annotation_created` (type: highlight | note | voice)

**Feed & social**
- `feed_viewed`
- `feed_item_liked` / `feed_item_unliked`
- `feed_item_commented`
- `post_shared` (destination)

**Groupes**
- `group_created` / `group_joined` / `group_left`
- `group_message_sent`

**Badges & gamification**
- `badge_unlocked` (badge_id)
- `streak_continued` / `streak_broken`
- `wrapped_opened` / `wrapped_shared`

**Monétisation**
- `paywall_viewed` (context)
- `subscription_started` (plan, price)
- `subscription_cancelled`

**Erreurs techniques** (auto via Sentry, pas besoin d'event PostHog)

Chaque event porte les propriétés globales : `platform`, `app_version`, `locale`, `supabase_user_id`, `is_premium`.

---

## 10. Consentement RGPD

1. Ajouter un écran de consentement au premier lancement (après onboarding, avant feed).
2. Toggle dans `profile` → "Paramètres" → "Confidentialité & analytics".
3. Stockage du choix dans `shared_preferences` (`analytics_consent_v1 = bool`).
4. `LoggingService.init()` respecte ce flag ; si refus, PostHog et Sentry ne sont pas initialisés (ou initialisés en mode "disabled").
5. Mettre à jour `privacy_policy_page.dart` pour nommer PostHog et Sentry explicitement (obligation RGPD).

**Note** : Sentry peut rester actif même sans consentement si on se limite aux erreurs techniques anonymisées (pas de userId, pas de breadcrumbs contenant du PII). À arbitrer avec le DPO / conseil juridique.

---

## 11. Session replay (optionnel — phase 2)

PostHog propose un session replay Flutter en bêta. À activer seulement si :
- Consentement explicite donné.
- Masquage des champs sensibles (emails, auth, contenus annotations personnelles).

Intérêt très fort pour debug UX, mais lourd en bande passante. **Hors scope v1**.

---

## 12. Plan d'implémentation par étapes

| Étape | Contenu | Effort | Livrable |
|-------|---------|--------|----------|
| 1 | Packages + env.json + `LoggingService` minimal (PostHog + Sentry init, identify, event, error) | 0,5 j | PR #1 |
| 2 | `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` dans main.dart | 0,5 j | PR #2 |
| 3 | `AnalyticsObserver` + nommage des routes principales | 1 j | PR #3 |
| 4 | Instrumentation auth (identify/reset dans `auth_gate`) | 0,5 j | PR #4 |
| 5 | Events métier v1 (10–15 events clés : book_added, reading_session_*, subscription_*, paywall_viewed, badge_unlocked) | 1,5 j | PR #5 |
| 6 | Wrapper `trace()` + instrumentation des 5 services critiques | 1 j | PR #6 |
| 7 | Écran consentement RGPD + toggle profil + mise à jour privacy policy | 1 j | PR #7 |
| 8 | Dashboard PostHog (funnels onboarding, rétention, conversion paywall) + alertes Sentry | 0,5 j | Config SaaS |

**Total estimé** : ~6,5 jours dev.

---

## 13. Ce qu'il faut pour démarrer

À ta charge :
1. Créer un projet PostHog EU (`eu.posthog.com`) et récupérer la clé projet.
2. Créer un projet Sentry (`sentry.io`) Flutter et récupérer le DSN.
3. Décider : active-t-on Sentry sans consentement explicite (erreurs techniques only) ? → impact sur UX onboarding.
4. Décider : masquage d'email/nom dans les events PostHog ou on garde l'id Supabase uniquement ?

Une fois ces 4 points tranchés, je peux démarrer l'étape 1 (PR #1) immédiatement.

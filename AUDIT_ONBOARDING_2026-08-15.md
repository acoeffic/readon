# Audit de l'entonnoir d'onboarding — 15 août 2026

Objectif : identifier, dans le code Flutter, les écrans où la cohorte d'août décroche.
Contexte chiffré : 21 inscrits en août, **19 avec une durée de vie de 0 jour**, 5 sessions de lecture démarrées, 2 lecteurs sur ≥2 jours, 0 sur ≥5 jours.

---

## 0. Le constat qui conditionne tout le reste

**Le funnel n'est pas mesuré — alors que toute l'infrastructure est déjà en place.**

- `posthog_flutter` est installé, `POSTHOG_API_KEY` et `POSTHOG_HOST` sont renseignés dans `env.json`.
- `lib/services/analytics_service.dart` est complet et propre : `init()`, `identify()`, `track()`, `screen()`, `setUserProperties()`, `optOut()`.
- La classe `AnalyticsEvent` définit **~35 noms d'events**, dont exactement ceux qu'il faudrait : `signup_completed`, `onboarding_step_viewed`, `onboarding_step_skipped`, `onboarding_completed`, `book_added`, `reading_session_started`, `paywall_shown`, `paywall_dismissed`…

Or, en cherchant les appels réels dans tout `lib/` :

| Event émis en production | Où |
|---|---|
| `logout` | `settings_page.dart` (×2) |
| `amazon_link_clicked` | `utils/amazon_affiliate.dart` |
| `feedback_submitted` | `services/feedback_service.dart` |
| 3 events de modération | `services/moderation_service.dart` |

**Aucun des events d'onboarding, de session de lecture, d'ajout de livre ou de paywall n'est jamais appelé.** Ils sont déclarés et jamais utilisés.

De plus, aucun `PosthogObserver` n'est monté dans `navigatorObservers` — le commentaire de `AnalyticsService.screen()` le recommande explicitement, mais ce n'est pas fait. Il n'y a donc même pas de tracking d'écran automatique en repli.

> Conséquence : sur les 6 utilisateurs d'août qui n'ont pas terminé l'onboarding, on ne peut pas savoir sur quelle étape ils se sont arrêtés. Tout ce qui suit est une lecture du code croisée avec les traces laissées en base — pas une mesure.

**C'est l'action n°1, et elle coûte une demi-journée** : une dizaine d'appels `AnalyticsService().track(...)` à poser dans `onboarding_page.dart`, `step_*.dart`, `start_reading_session_page_unified.dart` et `paywall_controller.dart`.

---

## 1. Le parcours réel, tel qu'il est codé

`AuthGate` (`lib/pages/auth/auth_gate.dart`) :
- pas de session → `LoginPage` (ou `MainNavigation` si mode invité déjà choisi) ;
- session + `onboarding_completed = false` → `OnboardingPage` ;
- session + `onboarding_completed = true` → `MainNavigation`.

`OnboardingPage` est un `PageView` en `NeverScrollableScrollPhysics` (navigation uniquement par boutons) qui se **ramifie selon `_readingHabit`** :

**Parcours « papier » — 5 écrans**
`StepWelcome` → `StepReadingHabit` → `StepManualAdd` → `StepSuggestedReaders` → `StepFirstSession`

**Parcours « liseuse » / « mix » — 7 écrans**
`StepWelcome` → `StepReadingHabit` → `StepKindleConnect` → `StepSyncProgress` → `StepSyncSuccess` → `StepSuggestedReaders` → `StepFirstSession`

`onboarding_completed` n'est écrit qu'à la toute fin, dans `_completeOnboarding()` ou `_startFirstSession()`. Un abandon à n'importe quelle étape laisse donc le flag à `false` — c'est ce qui explique les 6 profils « onboarding non terminé ».

### Ce que dit la base sur chaque branche (cohorte d'août)

| Parcours | Utilisateurs | Ont ajouté un livre | Ont démarré une session |
|---|---|---|---|
| `papier` | 9 | 6 (67 %) | **4 (44 %)** |
| `mix` | 4 | 2 | 1 |
| `liseuse` | 2 | 1 | **0** |
| onboarding non terminé | 6 | 1 | 0 |

**Le parcours Kindle (`liseuse` + `mix`) : 6 utilisateurs, 1 seule session de lecture.** Le parcours papier active 2,5 fois mieux, avec deux écrans de moins.

---

## 2. Écrans candidats au décrochage, par ordre de gravité

### #1 — `StepKindleConnect` : demander un login Amazon dans la première minute

`lib/pages/onboarding/widgets/step_kindle_connect.dart` → `KindleLoginPage` (WebView).

On demande à quelqu'un qui vient d'installer l'app de **saisir ses identifiants Amazon dans une WebView**. C'est la barrière de confiance maximale, posée au moment où l'app n'a encore rien prouvé.

Aggravant, dans `onboarding_page.dart` :

```dart
void _handleKindleResult(KindleReadingData? data) {
  if (data != null) {
    setState(() => _kindleData = data);
    _goToNext();
  }
  // If null (user cancelled), stay on kindle connect step
}
```

Si l'utilisateur **annule** le login Amazon, il revient sur l'écran de connexion Kindle, **sans message, sans progression, sans rien**. Le seul moyen d'avancer est un `TextButton` gris clair en bas. Un utilisateur qui hésite puis annule se retrouve face au même mur, et l'app a l'air cassée.

**Correctif** : inverser la hiérarchie (« Ajouter un livre à la main » en bouton principal, « Connecter mon Kindle » en secondaire), et avancer automatiquement — ou afficher une alternative explicite — quand `data == null`.

---

### #2 — L'empilement de modales à la sortie de l'onboarding

`lib/navigation/main_navigation.dart`, `addPostFrameCallback` :

```
_maybeShowPaywall()              → paywall natif Apple
_maybeStartOnboardingTutorial()  → overlays showcase
_checkAutoFreezeCelebration()
_maybeShowWatchSessionCatchup()
maybeShowChooseDisplayNameSheet()
```

Et `PaywallController` pose `markPendingAfterOnboarding()` à la fin de l'onboarding — donc **le paywall est la première chose que voit un utilisateur qui vient de terminer l'onboarding sans avoir lu une seule page**. Ensuite il revient **un lancement sur deux** (`_kAppOpenCountKey`, présentation sur les compteurs pairs).

Sur le parcours papier avec ajout de livre sauté, la séquence complète vécue est : 5 écrans d'onboarding → paywall → tutoriel → sheet « choisis ton pseudo ». Sans avoir jamais vu à quoi sert l'app.

**Correctif** : déclencher le paywall après la **première session terminée** (moment où l'utilisateur a compris la valeur), pas à la sortie de l'onboarding. Et espacer la récurrence.

---

### #3 — Permission notifications demandée avant tout

`auth_gate.dart`, bloc `finally` :

```dart
if (Supabase.instance.client.auth.currentUser != null) {
  await PushNotificationService().initialize();   // → requestPermission()
```

La popup système de notifications apparaît **dès le premier login**, avant même `StepWelcome`. Le refus est quasi certain à ce stade — et tu perds le canal de relance J1, exactement celui dont tu as besoin puisque 19 utilisateurs sur 21 ne reviennent jamais.

**Correctif** : déplacer `requestPermission()` à la fin de la première session de lecture réussie, avec un écran d'amorce qui explique le streak.

---

### #4 — `StepFirstSession` propose un livre arbitraire après import Kindle

`onboarding_page.dart`, `_handleSyncComplete()` :

```dart
if (books.isNotEmpty) _selectedBook = books.first;
```

`books.first` est le premier élément renvoyé par `getUserBooksWithStatus()`, sans filtre de statut ni tri. Après un import de 28 livres, le CTA « Lire » peut proposer un livre terminé il y a trois ans.

Le cas s'est produit : l'inscrit du **11/08 a 28 livres importés, 0 session, onboarding jamais terminé**. Import réussi, puis abandon.

**Correctif** : `_selectedBook` = livre au statut `reading`, sinon le plus récemment ajouté ; jamais `books.first` brut. Et proposer un choix quand il y a plus de 3 livres.

---

### #5 — Le mur du démarrage de session

`lib/pages/reading/start_reading_session_page_unified.dart`, `_startSession()` :

```dart
final pageNumber = _detectedPageNumber ?? _manualPageNumber;
if (pageNumber == null) {
  _errorMessage = l.captureOrEnterPage;
  return;
}
```

Impossible de démarrer sans numéro de page : soit photo + OCR (permission caméra, qualité de scan), soit saisie manuelle. C'est la **première action réelle** demandée à l'utilisateur, et elle exige une manipulation physique du livre.

Nuance importante, et plutôt rassurante : **une fois démarrée, une session se termine** — 3 sessions non terminées sur 63 en août (5 %). Le problème est donc **avant** le démarrage, pas pendant.

Mais sur les 5 utilisateurs d'août ayant démarré une session, **2 ne l'ont jamais terminée** (inscrits du 05/08 et du 10/08, une session chacun, `end_time` nul). Ils ont lancé le chrono et ne sont jamais revenus le fermer. Pour ces deux-là, l'app est restée bloquée en « session en cours » — ce qui rend le retour encore moins engageant.

**Correctif** : proposer un démarrage « page 1 » ou « reprendre où j'en étais » en un tap, sans photo ni saisie. Et fermer automatiquement une session ouverte depuis plus de N heures avec une estimation, au lieu de la laisser béante.

---

### #6 — Le mode invité est un trou noir

`login_page.dart` ligne ~644 : `Continuer sans compte` → `enterGuestMode()` → `MainNavigation`.
En mode invité : onglets 1 et 3 bloqués, pas de paywall, pas de tutoriel, **jamais d'onboarding**, aucune ligne en base, aucun event.

Entre **29 téléchargements** et **21 comptes créés** en août, il y a jusqu'à 8 personnes dont tu ne sais strictement rien : ont-elles bounce sur l'écran de login, ou tourné en mode invité avant de partir ?

**Correctif** : au minimum tracker `guest_mode_entered` et les écrans vus en invité (PostHog fonctionne en anonyme, `personProfiles = always` est déjà configuré pour ça).

---

### #7 — `StepSuggestedReaders` sur une communauté de 50 comptes

`get_suggested_readers` avec `p_limit: 15`, sur une base de 50 profils au total. L'auto-skip quand la liste est vide est bien vu. Mais si la RPC renvoie 2 ou 3 inconnus sans activité, l'écran coûte un tap et ne produit rien — pour un utilisateur qui n'a toujours pas lu une page.

**Correctif** : masquer l'étape en dessous d'un seuil (par ex. moins de 5 lecteurs suggérés réellement actifs), et la reproposer plus tard dans le cycle de vie.

---

## 3. Point corrigé

`profiles.has_completed_first_session` n'est **pas** incohérent, contrairement à ce que suggérait la lecture rapide des données. Il est écrit par `ContactsService.markFirstSessionCompleted()`, appelé uniquement depuis `end_reading_session_page.dart` — donc à la **fin** d'une session, jamais au démarrage. Les deux utilisateurs à `false` malgré une ligne dans `reading_sessions` sont précisément ceux dont la session n'a jamais été terminée. Le flag est correct ; c'est sa sémantique qui prête à confusion (« a terminé une session », pas « a lu »).

À noter tout de même : l'appel est enveloppé dans `.timeout(_kPostSessionTimeout).catchError((_) {})` — un échec réseau est avalé silencieusement et le flag reste `false` définitivement, sans nouvelle tentative.

---

## 4. Plan d'action, par ordre de rendement

| # | Action | Effort | Pourquoi |
|---|---|---|---|
| 1 | **Instrumenter l'onboarding** : `onboarding_step_viewed` (avec nom d'étape + `reading_habit`), `onboarding_step_skipped`, `onboarding_completed`, `book_added`, `reading_session_started`, `paywall_shown` / `paywall_dismissed`. Monter `PosthogObserver`. | ½ j | Sans ça, tout le reste est du pari |
| 2 | **Sortir le paywall de la fin d'onboarding** → après la 1re session terminée | 1 h | Le plus gros irritant, le plus facile à retirer |
| 3 | **Retarder la permission push** → fin de première session | 1 h | Récupère le canal de relance J1 |
| 4 | **Dépiéger le parcours Kindle** : papier en primaire, avancer si annulation | ½ j | Le parcours qui active 2,5× moins |
| 5 | **`_selectedBook` intelligent** au lieu de `books.first` | 30 min | Bug de pertinence sur le dernier écran |
| 6 | **Démarrage de session en un tap** (page 1 / reprendre) | 1 j | Retire le mur OCR de la première action |
| 7 | **Tracker le mode invité** | 1 h | Éclaire 8 des 29 téléchargements |
| 8 | **Relancer les 19 dormants d'août** — `reengagement_last_bucket` / `reengagement_last_sent_at` existent déjà | ½ j | Récupération directe |

Les points 2 et 3 sont deux heures de travail combinées et touchent les deux irritants les plus violents du parcours. Le point 1 est celui qui rend tous les suivants mesurables.

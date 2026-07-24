# Spec — Ajouter une lecture passée (saisie manuelle a posteriori)

> Statut : **implémentée le 20/07/2026** (migration `is_manual` appliquée en base). Reste : `flutter gen-l10n` + tests manuels ci-dessous.
> Origine : retour utilisatrice ("j'ai lu dans le train, j'ai oublié de lancer le chrono").
> Parallèle produit : les trackers d'allaitement — l'oubli du chrono est le cas
> d'usage le plus fréquent d'un tracker, pas un cas limite. La saisie a
> posteriori est table stakes.

## Objectif

Permettre d'enregistrer une session de lecture **déjà effectuée aujourd'hui**
sans avoir lancé le chrono : pages début/fin + durée. La session doit compter
partout comme une session normale : feed, streak/flow, stats, défis, widget,
progression du livre.

## Décisions produit (V1)

- **Antidatage autorisé, mais sans effet sur le streak.** On peut enregistrer
  une lecture d'un jour passé (date max : aujourd'hui, borne basse : 1 an) ;
  elle compte pour les stats, le feed, la progression du livre et les défis,
  mais **pas pour le calcul de la flamme** — pouvoir réparer son streak a
  posteriori le dévaloriserait. Une lecture manuelle saisie **le jour même**
  compte normalement pour la flamme.
  - Règle d'exclusion (persistante, sans colonne supplémentaire) : une session
    est "antidatée" si `is_manual == true` **et** `date locale(end_time) ≠
    date locale(created_at)`. À implémenter dans `_sessionCountsForFlow`
    (`lib/services/flow_service.dart` L20-38), seul point de calcul du flow
    (client-side) — les badges de flow et le widget en héritent
    automatiquement.
  - Edge case assumé : une lecture d'hier soir saisie juste après minuit est
    considérée antidatée (ne compte pas pour la flamme d'hier). Cohérent avec
    la règle, à documenter dans l'UI par l'avertissement ci-dessous.
- **Pas de photo/OCR obligatoire** : saisie manuelle simple, l'OCR reste
  possible (réutiliser le bouton scanner du dialogue de rattrapage Watch).
- **Anti-triche** : rien de spécifique en V1. Tricher est déjà possible en
  laissant tourner le chrono. Les caps existants (`is_too_fast`,
  `is_too_long`) s'appliquent naturellement.
- **Colonne `is_manual`** : oui, migration légère `BOOLEAN DEFAULT FALSE`,
  pour pouvoir distinguer plus tard (stats, wording feed, exclusions). Aucun
  usage UI en V1.

## UX

### Point d'entrée

**`BookDetailPage`** (dans `lib/pages/books/user_books_page.dart`, bloc
actions ~L2080-2121) : bouton secondaire **"Ajouter une lecture passée"**
sous "Commencer une lecture", visible si le livre n'est ni terminé ni en
session active. On ne touche pas au FAB global (il est dédié au temps réel) —
éventuel 3e item de menu en V2 si la feature est peu découverte.

### Formulaire

Page dédiée `AddPastSessionPage` (sœur de
`start_reading_session_page_unified.dart`, même style de hero card livre) :

- **Page de début** — pré-remplie à la dernière page connue du livre
  (même logique que `_handleStart` du Watch service : `current_page` sinon 1).
- **Page de fin** — champ vide, autofocus, bouton "Scanner la page" (OCR),
  même pattern que `WatchSessionCatchupDialog`.
- **Durée** — chips rapides 15 / 30 / 45 / 60 min + champ libre minutes.
- **Date** — par défaut aujourd'hui ; date picker borné [aujourd'hui − 1 an,
  aujourd'hui]. Si une date passée est choisie, afficher un bandeau info non
  bloquant : "Cette lecture comptera dans tes stats mais pas pour ta flamme."
- **Heure de fin** — par défaut "à l'instant" (ou 21:00 pour un jour passé) ;
  sélecteur d'heure optionnel. `end_time - durée` doit rester dans la même
  journée, sinon tronquer `start_time` à 00:00 (le flow ne regarde que
  `end_time`).
- CTA **"Enregistrer la lecture"** → toast de confirmation + retour à la
  fiche livre (rafraîchir `_loadSessionData()`).

### Validations

- `endPage >= startPage` (contrainte DB
  `CHECK (end_page IS NULL OR end_page >= start_page)`, migration 20260609) —
  réutiliser la clé l10n `endPageBeforeStartDetailed`.
- Durée ≥ 2 min et pages ≥ 1, sinon avertir que la session ne comptera pas
  pour la flamme (`_sessionCountsForFlow` : `pagesRead >= 1 && duration >= 2
  min`) — avertissement non bloquant. (Sans objet si date passée : déjà
  exclue de la flamme.)
- Pas de date future ; date passée limitée à 1 an.
- Bloquer si une **session active existe sur ce livre** (message : "termine
  d'abord ta session en cours") pour éviter les incohérences de page courante.
  Session active sur un *autre* livre : autorisé.

## Technique

### Service — `ReadingSessionService.insertPastSession(...)`

```dart
Future<ReadingSession> insertPastSession({
  required String bookId,
  required int startPage,
  required int endPage,
  required Duration duration,
  DateTime? endTime, // défaut : maintenant ; borné [now - 1 an, now]
})
```

**Insert-then-update obligatoire** (pas un insert unique déjà terminé) : le
trigger feed (`20260530_drop_recreate_activity_trigger_and_assert.sql`) est
**AFTER UPDATE only**, avec garde sur la transition `end_time NULL → NOT
NULL`. Un INSERT avec `end_time` déjà rempli ne créerait **pas** l'activité
feed. Donc :

1. `INSERT` ligne ouverte : `book_id`, `user_id`, `start_page`,
   `start_time = endTime - duration`, `is_manual = true`.
2. `UPDATE` immédiat de la même ligne : `end_page`, `end_time` → déclenche le
   trigger feed (dédup par `session_id` déjà en place), le streak et la
   progression livre suivent automatiquement (la page courante d'un livre
   dérive du `end_page` de la dernière session, cf.
   `getCurrentReadingBook()`).
   - Antidatage : vérifier que `getCurrentReadingBook()` prend bien la
     dernière session **chronologique** (tri par date) — une session
     antidatée plus ancienne ne doit pas faire reculer la page courante du
     livre. Ajouter un test.
3. Ne **pas** passer par `endSession()` : il calcule `end_time = now -
   pauses` et démarre/termine la Live Activity — rien de tout ça ne s'applique
   ici.

Fenêtre transitoire : entre 1 et 2, la session apparaît "active" (~quelques
centaines de ms). Enchaîner les deux appels sans await intermédiaire coûteux ;
acceptable en V1 (au pire la Watch reçoit un pushState furtif).

### Hooks post-création (répliquer la fin de session normale, tout non bloquant)

- `ChallengeService.updateProgressAfterSession(bookId, pagesRead,
  durationMinutes)` — sinon les défis ne bougent pas (appelé aujourd'hui
  uniquement par `endSession`, `updateSessionPages` et l'offline queue).
- `WidgetService().updateWidget()` — widget iOS + push état Watch.
- `_notifyActiveSessionsChanged()` — rafraîchit bannière/FAB/flow stream.
- Badges : `checkAndAwardBadges()` + `checkSecretBadges(sessionId: …)` +
  `checkAndAwardFlowBadges()`, avec les dialogues d'unlock, comme dans
  `end_reading_session_page.dart` (~L245-300).
- **Pas de Live Activity** (sessions temps réel uniquement).

### Migration

```sql
ALTER TABLE reading_sessions ADD COLUMN is_manual BOOLEAN NOT NULL DEFAULT FALSE;
```

+ modèle `ReadingSession` (`isManual`, `fromJson`/`toJson`/`copyWith`).

### Offline

V1 : exiger le réseau (message d'erreur propre). L'`offline_session_queue`
est conçue pour le flux start/end temps réel ; l'étendre au flux manuel est
un chantier V2.

## i18n (fr/en/es + `flutter gen-l10n`)

`addPastSessionButton`, `addPastSessionTitle`, `addPastSessionDuration`,
`addPastSessionEndTime`, `addPastSessionSave`, `addPastSessionSaved`,
`addPastSessionTooShortWarning`, `addPastSessionActiveSessionError`.
Réutiliser : `watchCatchupStartPage`, `watchCatchupEndPage`,
`watchCatchupScan`, `endPageBeforeStartDetailed`.

## Fichiers touchés (estimation)

| Fichier | Nature |
|---|---|
| `supabase/migrations/2026XXXX_add_is_manual_to_reading_sessions.sql` | nouveau |
| `lib/models/reading_session.dart` | +`isManual` |
| `lib/services/reading_session_service.dart` | +`insertPastSession` |
| `lib/services/flow_service.dart` | `_sessionCountsForFlow` : exclure les sessions antidatées (`is_manual && date(end_time) ≠ date(created_at)`) |
| `lib/pages/reading/add_past_session_page.dart` | nouveau (ConstrainedContent !) |
| `lib/pages/books/user_books_page.dart` | bouton d'entrée BookDetailPage |
| `lib/l10n/app_{fr,en,es}.arb` | +8 clés |

## Tests manuels

1. Livre en cours, aucune session active → ajouter 30 min p.54→p.80 →
   vérifier : feed (1 seule activité), flamme du jour allumée, page courante
   80, défis avancés, widget à jour, Watch à jour.
2. Durée 1 min → avertissement flamme, session créée quand même, flamme
   inchangée.
3. Page fin < page début → erreur bloquante.
4. Session active sur le même livre → entrée bloquée avec message.
5. Session active sur un autre livre → OK, la session active n'est pas
   affectée.
6. Double soumission rapide → une seule activité feed (dédup trigger).
7. Lecture antidatée (ex. avant-hier) → apparaît dans le feed/stats à la
   bonne date, défis avancés, mais flamme **inchangée** (ni allumée ce
   jour-là, ni streak réparé) ; le modèle `ReadingSession` doit exposer
   `createdAt` pour le calcul.
8. Lecture antidatée avec `end_page` < page courante actuelle → la page
   courante du livre ne recule pas.
9. Lecture manuelle du jour même → flamme allumée normalement (cas nominal
   du train).

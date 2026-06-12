# CLAUDE.md - Conventions projet LexDay

## iPad / Responsive

- L'app supporte iPhone et iPad via `lib/utils/responsive.dart`
- **Toute nouvelle page** doit wrapper son body dans `ConstrainedContent` pour que le contenu soit centré et contraint à 600px sur iPad :
  ```dart
  import '../../widgets/constrained_content.dart';

  body: ConstrainedContent(
    child: SingleChildScrollView(
      // contenu...
    ),
  ),
  ```
- Sur iPhone, `ConstrainedContent` retourne l'enfant tel quel (zero impact)
- La navigation utilise `NavigationRail` sur iPad, `BottomAppBar` sur iPhone (géré dans `main_navigation.dart`)

## Internationalisation (i18n)

- L'app supporte **français** et **anglais** via Flutter `gen-l10n`
- Les fichiers de traduction sont dans `lib/l10n/` :
  - `app_fr.arb` — chaînes françaises (template)
  - `app_en.arb` — traductions anglaises
- **Toute nouvelle chaîne de texte** visible par l'utilisateur doit être ajoutée dans les deux fichiers `.arb` et référencée via `AppLocalizations` :
  ```dart
  import '../../l10n/app_localizations.dart';

  // Dans build() ou une méthode avec context :
  final l10n = AppLocalizations.of(context);
  Text(l10n.myKey)
  ```
- Pour les chaînes avec paramètres, utiliser la syntaxe ICU dans le `.arb` :
  ```json
  "greeting": "Bonjour {name}",
  "@greeting": {
    "placeholders": {
      "name": {"type": "String"}
    }
  }
  ```
- **Ne jamais** coder en dur du texte français/anglais dans les widgets — toujours passer par `AppLocalizations`
- Après modification des `.arb`, lancer `flutter gen-l10n` pour régénérer les classes
- Les `const` doivent être retirés des widgets qui utilisent `AppLocalizations.of(context)` (valeur runtime)

## Badges

- **Source de vérité du catalogue** : `badges.md` à la racine du projet. Chaque badge y est listé dans une cellule de tableau Markdown au format `` | `id` | icône | nom | ... | `` (l'id est en lowercase + underscores + digits, ex: `books_5`, `streak_7_days`).
- **Source de vérité des visuels (bundle app)** : `assets/badges/<id>.webp` (WebP 384×384, ~30 KB chacun, un seul fichier par badge, pas de variantes `_light`/`_dark`).
- **Sources HD** : PNG 1254×1254 dans le bucket Supabase `asset/Image/badge/badges_renamed/`. Pour régénérer les WebP : `cwebp -q 85 -resize 384 384 <id>.png -o assets/badges/<id>.webp`.
- **Convention de nommage stricte** : le nom du fichier WebP est *exactement* l'id du badge. Pour `books_5` → `assets/badges/books_5.webp`. Aucun préfixe, aucun espace, aucun accent.
- **Vérification de synchro** : `dart run tool/check_badges.dart` parse `badges.md`, scanne `assets/badges/`, et affiche un rapport en trois catégories : OK / À dessiner / Orphelins. Exit code 1 si désynchronisé.
- **Supprimer les visuels orphelins** : `dart run tool/check_badges.dart --delete-orphans` (demande confirmation).
- **Ajouter un badge** = 4 endroits à toucher, dans cet ordre :
  1. Déposer le PNG source dans le bucket Supabase `Image/badge/badges_renamed/<id>.png`
  2. Ajouter la ligne dans `badges.md` (avec son id, sa catégorie, sa condition)
  3. Insérer l'entrée correspondante en base Supabase (table `badges`)
  4. Générer le WebP : `cwebp -q 85 -resize 384 384 <id>.png -o assets/badges/<id>.webp`
- **Supprimer un badge** = mêmes endroits dans l'ordre inverse : supprimer le WebP (`--delete-orphans` après suppression de la ligne md), supprimer la ligne dans `badges.md`, supprimer l'entrée Supabase, supprimer le PNG dans le bucket.
- Le dossier `assets/badges/` est déjà déclaré dans `pubspec.yaml` (`assets:` section) avec un `/` final : tous les WebP ajoutés sont embarqués automatiquement, pas besoin de les lister un par un.

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

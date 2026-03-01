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

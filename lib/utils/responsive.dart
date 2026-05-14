import 'package:flutter/widgets.dart';

class Responsive {
  static const double tabletBreakpoint = 600.0;
  static const double contentMaxWidth = 600.0;

  /// Largeur max pour les pages "contenu" (Feed, Library, Profile, Stats…).
  /// Plus large que [contentMaxWidth] qui reste réservé aux formulaires.
  static const double wideContentMaxWidth = 1100.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
  }

  /// True pour les écrans larges (iPad full-screen, ≥ 900 px) — utilisé pour
  /// activer les layouts multi-colonnes. Diffère de [isTablet] qui détecte
  /// même un iPad en split view 1/3 (étroit ; on garde alors le layout phone).
  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900.0;
  }
}

// lib/features/badges/widgets/first_book_badge_painter.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../config/env.dart';
import '../../../widgets/badge_display.dart';

/// Vérifie si un badge est le badge "Premier Livre" (1er livre terminé).
bool isFirstBookBadge({required String id, String? category, int? requirement}) {
  if (id == 'books_1' || id == 'first_book') return true;
  if (category == 'books_completed' && requirement == 1) return true;
  return false;
}

/// Vérifie si un badge est le badge "Apprenti Lecteur" (5 livres terminés).
bool isApprenticeReaderBadge({required String id, String? category, int? requirement}) {
  if (id == 'books_5') return true;
  if (category == 'books_completed' && requirement == 5) return true;
  return false;
}

/// Vérifie si un badge est le badge "Lecteur Confirmé" (10 livres terminés).
bool isConfirmedReaderBadge({required String id, String? category, int? requirement}) {
  if (id == 'books_10') return true;
  if (category == 'books_completed' && requirement == 10) return true;
  return false;
}

/// Vérifie si un badge est le badge "Bibliophile" (25 livres terminés).
bool isBibliophileBadge({required String id, String? category, int? requirement}) {
  if (id == 'books_25') return true;
  if (category == 'books_completed' && requirement == 25) return true;
  return false;
}

/// Widget réutilisable pour afficher le badge Premier Livre.
class FirstBookBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const FirstBookBadge({
    super.key,
    this.size = 80,
    this.isLocked = false,
  });

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget badge = SvgPicture.network(
      '${Env.supabaseStorageUrl}/asset/Image/badge_premier_chapitre.svg',
      width: size,
      height: size,
    );

    if (isLocked) {
      badge = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(
          opacity: 0.45,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

/// Widget réutilisable pour afficher le badge Apprenti Lecteur (5 livres).
class ApprenticeReaderBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const ApprenticeReaderBadge({
    super.key,
    this.size = 80,
    this.isLocked = false,
  });

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget badge = SvgPicture.network(
      '${Env.supabaseStorageUrl}/asset/Image/badge_apprenti_lecteur.svg',
      width: size,
      height: size,
    );

    if (isLocked) {
      badge = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(
          opacity: 0.45,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

/// Widget réutilisable pour afficher le badge Bibliophile (25 livres).
/// Utilise un SVG light/dark selon le thème.
class BibliophileBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const BibliophileBadge({
    super.key,
    this.size = 80,
    this.isLocked = false,
  });

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variant = isDark ? 'dark' : 'light';

    Widget badge = SvgPicture.network(
      '${Env.supabaseStorageUrl}/asset/Image/badge/badge_books_25_$variant.svg',
      width: size,
      height: size,
    );

    if (isLocked) {
      badge = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(
          opacity: 0.45,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

/// Widget pour le badge "Lecteur Confirmé" (10 livres).
/// SVG light/dark depuis Supabase Storage + animations BadgeDisplay.
class ConfirmedReaderBadge extends StatelessWidget {
  final double size;
  final bool isLocked;
  final bool animate;
  final bool showUnlockBurst;

  const ConfirmedReaderBadge({
    super.key,
    this.size = 80,
    this.isLocked = false,
    this.animate = false,
    this.showUnlockBurst = false,
  });

  static final _baseUrl =
      '${Env.supabaseStorageUrl}/asset/Image/badge/badge_books_10';

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (animate && !isLocked) {
      return BadgeDisplay(
        svgBasePath: _baseUrl,
        size: size,
        animate: true,
        showUnlockBurst: showUnlockBurst,
        tierColorLight: const Color(0xFFFFD700),
        tierColorDark: const Color(0xFFFFD700),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variant = isDark ? 'dark' : 'light';

    Widget badge = SvgPicture.network(
      '${_baseUrl}_$variant.svg',
      width: size,
      height: size,
    );

    if (isLocked) {
      badge = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(
          opacity: 0.45,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

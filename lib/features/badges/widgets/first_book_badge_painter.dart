// lib/features/badges/widgets/first_book_badge_painter.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      'https://nzbhmshkcwudzydeahrq.supabase.co/storage/v1/object/public/asset/Image/badge_premier_chapitre.svg',
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
      'https://nzbhmshkcwudzydeahrq.supabase.co/storage/v1/object/public/asset/Image/badge_apprenti_lecteur.svg',
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

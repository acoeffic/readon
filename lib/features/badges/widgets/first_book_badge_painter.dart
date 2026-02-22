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

/// Vérifie si un badge est le badge "Une Heure de Magie" (1h de lecture cumulée).
bool isOneHourMagicBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_1h') return true;
  if (category == 'reading_time' && requirement == 60) return true;
  return false;
}

/// Vérifie si un badge est le badge "Lecteur du Dimanche" (10h de lecture cumulées).
bool isSundayReaderBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_10h') return true;
  if (category == 'reading_time' && requirement == 600) return true;
  return false;
}

/// Vérifie si un badge est le badge "Passionné" (50h de lecture cumulées).
bool isPassionateBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_50h') return true;
  if (category == 'reading_time' && requirement == 3000) return true;
  return false;
}

/// Vérifie si un badge est le badge "Centurion" (100h de lecture cumulées).
bool isCenturionBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_100h') return true;
  if (category == 'reading_time' && requirement == 6000) return true;
  return false;
}

/// Vérifie si un badge est le badge "Marathonien" (250h de lecture cumulées).
bool isMarathonBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_250h') return true;
  if (category == 'reading_time' && requirement == 15000) return true;
  return false;
}

/// Vérifie si un badge est le badge "Demi-Millénaire" (500h de lecture cumulées).
bool isHalfMillenniumBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_500h') return true;
  if (category == 'reading_time' && requirement == 30000) return true;
  return false;
}

/// Vérifie si un badge est le badge "Millénaire" (1000h de lecture cumulées).
bool isMillenniumBadge({required String id, String? category, int? requirement}) {
  if (id == 'time_1000h') return true;
  if (category == 'reading_time' && requirement == 60000) return true;
  return false;
}

/// Vérifie si un badge est le badge "Fondateur de Club" (créer un club de lecture).
bool isClubFounderBadge({required String id, String? category, int? requirement}) {
  if (id == 'social_club_founder') return true;
  return false;
}

/// Vérifie si un badge est le badge "Leader" (club avec 10+ membres).
bool isClubLeaderBadge({required String id, String? category, int? requirement}) {
  if (id == 'social_club_leader') return true;
  return false;
}

/// Vérifie si un badge est le badge "Résident" (1 an sur LexDay).
bool isResidentBadge({required String id, String? category, int? requirement}) {
  if (id == 'seniority_1y') return true;
  return false;
}

/// Vérifie si un badge est le badge "Habitué" (2 ans sur LexDay).
bool isHabitueBadge({required String id, String? category, int? requirement}) {
  if (id == 'seniority_2y') return true;
  return false;
}

/// Vérifie si un badge est le badge "Pilier" (3 ans sur LexDay).
bool isPilierBadge({required String id, String? category, int? requirement}) {
  if (id == 'seniority_3y') return true;
  return false;
}

/// Vérifie si un badge est le badge "Monument" (5 ans sur LexDay).
bool isMonumentBadge({required String id, String? category, int? requirement}) {
  if (id == 'seniority_5y') return true;
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

/// Widget réutilisable pour afficher le badge "Une Heure de Magie" (1h de lecture).
class OneHourMagicBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OneHourMagicBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_01_heure_magie.svg',
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

/// Widget réutilisable pour afficher le badge "Lecteur du Dimanche" (10h de lecture).
class SundayReaderBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const SundayReaderBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_02_lecteur_dimanche.svg',
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

/// Widget réutilisable pour afficher le badge "Passionné" (50h de lecture).
class PassionateBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const PassionateBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_03_passionne.svg',
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

/// Widget réutilisable pour afficher le badge "Centurion" (100h de lecture).
class CenturionBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const CenturionBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_04_centurion.svg',
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

/// Widget réutilisable pour afficher le badge "Marathonien" (250h de lecture).
class MarathonBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const MarathonBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_05_marathonien.svg',
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

/// Widget réutilisable pour afficher le badge "Millénaire" (1000h de lecture).
class MillenniumBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const MillenniumBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_07_millenaire.svg',
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

/// Widget réutilisable pour afficher le badge "Demi-Millénaire" (500h de lecture).
class HalfMillenniumBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const HalfMillenniumBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/heures/badge_hours_06_demi_millenaire.svg',
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

/// Widget réutilisable pour afficher le badge "Fondateur de Club" (créer un club).
class ClubFounderBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const ClubFounderBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Club/badge_fondateur_club.svg',
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

/// Widget réutilisable pour afficher le badge "Leader" (club 10+ membres).
class ClubLeaderBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const ClubLeaderBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Club/badge_leader.svg',
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

/// Widget réutilisable pour afficher le badge "Résident" (1 an sur LexDay).
class ResidentBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const ResidentBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Anciennete_LexDay/badge_ancien_01_resident.svg',
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

/// Widget réutilisable pour afficher le badge "Habitué" (2 ans sur LexDay).
class HabitueBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const HabitueBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Anciennete_LexDay/badge_ancien_02_habitue.svg',
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

/// Widget réutilisable pour afficher le badge "Pilier" (3 ans sur LexDay).
class PilierBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const PilierBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Anciennete_LexDay/badge_ancien_03_pilier.svg',
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

/// Widget réutilisable pour afficher le badge "Monument" (5 ans sur LexDay).
class MonumentBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const MonumentBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Anciennete_LexDay/badge_ancien_04_monument.svg',
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

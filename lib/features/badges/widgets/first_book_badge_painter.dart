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

/// Vérifie si un badge est le badge "Un par Mois sur un an" (1 livre/mois pendant 12 mois).
bool isAnnualOnePerMonthBadge({required String id, String? category, int? requirement}) {
  if (id == 'annual_1_per_month') return true;
  if (category == 'annual_books' && requirement == 12) return true;
  return false;
}

/// Vérifie si un badge est le badge "24 livres par an" (2 livres/mois, cadence soutenue).
bool isAnnualTwoPerMonthBadge({required String id, String? category, int? requirement}) {
  if (id == 'annual_2_per_month') return true;
  if (category == 'annual_books' && requirement == 24) return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Un par Mois sur un an".
class AnnualOnePerMonthBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const AnnualOnePerMonthBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Livre_annuel/badge_annual_01_un_par_mois.svg',
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

/// Vérifie si un badge est le badge "52 par an" (1 livre/semaine, métronome).
bool isAnnualOnePerWeekBadge({required String id, String? category, int? requirement}) {
  if (id == 'annual_1_per_week') return true;
  if (category == 'annual_books' && requirement == 52) return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "24 livres par an" (Cadence).
class AnnualTwoPerMonthBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const AnnualTwoPerMonthBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Livre_annuel/badge_annual_02_cadence.svg',
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

/// Vérifie si un badge est le badge "Centenaire" (100 livres par an).
bool isAnnualCentenaireBadge({required String id, String? category, int? requirement}) {
  if (id == 'annual_centenaire') return true;
  if (category == 'annual_books' && requirement == 100) return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "52 par an" (Métronome).
class AnnualOnePerWeekBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const AnnualOnePerWeekBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Livre_annuel/badge_annual_03_metronome.svg',
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

/// Vérifie si un badge est le badge "Prise de la Bastille" (14 juillet).
bool isOccasionBastilleDayBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_bastille_day') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Prise de la Bastille".
class OccasionBastilleDayBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionBastilleDayBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_bastille_day.svg',
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

/// Vérifie si un badge est le badge "Lecture de Noël" (25 décembre).
bool isOccasionChristmasBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_christmas') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture de Noël".
class OccasionChristmasBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionChristmasBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_christmas_read.svg',
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

/// Vérifie si un badge est le badge "Lecture en musique" (21 juin).
bool isOccasionFeteMusiqueBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_fete_musique') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture en musique".
class OccasionFeteMusiqueBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionFeteMusiqueBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_fete_musique.svg',
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

/// Vérifie si un badge est le badge "Lecture frisson" (31 octobre).
bool isOccasionHalloweenBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_halloween') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture frisson".
class OccasionHalloweenBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionHalloweenBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_halloween.svg',
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

/// Vérifie si un badge est le badge "Lecture au soleil" (15 août).
bool isOccasionSummerReadBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_summer_read') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture au soleil".
class OccasionSummerReadBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionSummerReadBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_summer_read.svg',
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

/// Vérifie si un badge est le badge "Lecture de l'amour" (14 février).
bool isOccasionValentineBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_valentine') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture de l'amour".
class OccasionValentineBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionValentineBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_valentine_read.svg',
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

/// Vérifie si un badge est le badge "Lecture du Réveillon" (31 décembre).
bool isOccasionNyeBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_nye') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture du Réveillon".
class OccasionNyeBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionNyeBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_nye_read.svg',
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

/// Vérifie si un badge est le badge "Pause méritée" (1er mai).
bool isOccasionLabourDayBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_labour_day') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Pause méritée".
class OccasionLabourDayBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionLabourDayBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_labour_day.svg',
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

bool isOccasionWorldBookDayBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_world_book_day') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Journée du livre".
class OccasionWorldBookDayBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionWorldBookDayBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_world_book_day.svg',
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

bool isOccasionNewYearBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_new_year') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Premier Chapitre de l'Année".
class OccasionNewYearBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionNewYearBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_evt_new_year.svg',
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

bool isOccasionEasterBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_easter') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Lecture de Pâques".
class OccasionEasterBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionEasterBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_evt_paques.svg',
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

bool isOccasionAprilFoolsBadge({required String id, String? category, int? requirement}) {
  if (id == 'occasion_april_fools') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Poisson d'Avril".
class OccasionAprilFoolsBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const OccasionAprilFoolsBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Occasion/badge_evt_poisson_avril.svg',
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

bool isGenreSfInitieBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_sf_initie') return true;
  return false;
}

bool isGenrePolarApprentiBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_polar_apprenti') return true;
  return false;
}

bool isGenrePolarAdepteBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_polar_adepte') return true;
  return false;
}

bool isGenrePolarMaitreBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_polar_maitre') return true;
  return false;
}

bool isGenrePolarLegendeBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_polar_legende') return true;
  return false;
}

bool isGenreSfApprentiBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_sf_apprenti') return true;
  return false;
}

bool isGenreSfAdepteBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_sf_adepte') return true;
  return false;
}

bool isGenreSfMaitreBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_sf_maitre') return true;
  return false;
}

bool isGenreSfLegendeBadge({required String id, String? category, int? requirement}) {
  if (id == 'genre_sf_legende') return true;
  return false;
}

/// Widget réutilisable pour afficher le badge "Initié" (SF).
class GenreSfInitieBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenreSfInitieBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Science-Fiction/badge_sf_01_initie.svg',
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

/// Widget réutilisable pour afficher le badge "Apprenti" (Polar/Thriller, 5 livres).
class GenrePolarApprentiBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenrePolarApprentiBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Polar/badge_sf_01_apprenti.svg',
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

/// Widget réutilisable pour afficher le badge "Adepte" (Polar/Thriller, 15 livres).
class GenrePolarAdepteBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenrePolarAdepteBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Polar/badge_sf_02_adepte.svg',
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

/// Widget réutilisable pour afficher le badge "Maitre" (Polar/Thriller, 30 livres).
class GenrePolarMaitreBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenrePolarMaitreBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Polar/badge_sf_03_maitre.svg',
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

/// Widget réutilisable pour afficher le badge "Legende" (Polar/Thriller, 50 livres).
class GenrePolarLegendeBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenrePolarLegendeBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Polar/badge_sf_04_legende.svg',
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

/// Widget réutilisable pour afficher le badge "Apprenti" (SF, 5 livres).
class GenreSfApprentiBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenreSfApprentiBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Science-Fiction/badge_sf_01_apprenti.svg',
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

/// Widget réutilisable pour afficher le badge "Adepte" (SF, 15 livres).
class GenreSfAdepteBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenreSfAdepteBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Science-Fiction/badge_sf_02_adepte.svg',
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

/// Widget réutilisable pour afficher le badge "Maitre" (SF, 30 livres).
class GenreSfMaitreBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenreSfMaitreBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Science-Fiction/badge_sf_03_maitre.svg',
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

/// Widget réutilisable pour afficher le badge "Legende" (SF, 50 livres).
class GenreSfLegendeBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const GenreSfLegendeBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/genre/Science-Fiction/badge_sf_04_legende.svg',
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

/// Widget réutilisable pour afficher le badge "Centenaire" (100 par an).
class AnnualCentenaireBadge extends StatelessWidget {
  final double size;
  final bool isLocked;

  const AnnualCentenaireBadge({
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
      '${Env.supabaseStorageUrl}/asset/Image/badge/Livre_annuel/badge_annual_04_centenaire.svg',
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

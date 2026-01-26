// lib/models/reading_streak.dart
// Modèle pour représenter les streaks de lecture (jours consécutifs)

import 'streak_freeze.dart';

class ReadingStreak {
  final int currentStreak;      // Nombre de jours consécutifs actuels
  final int longestStreak;      // Record de jours consécutifs
  final DateTime? lastReadDate; // Dernière date de lecture
  final List<DateTime> readDates; // Historique des dates de lecture
  final List<DateTime> frozenDates; // Dates protégées par un freeze
  final StreakFreezeStatus? freezeStatus; // Statut du freeze

  ReadingStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastReadDate,
    required this.readDates,
    this.frozenDates = const [],
    this.freezeStatus,
  });

  factory ReadingStreak.empty() {
    return ReadingStreak(
      currentStreak: 0,
      longestStreak: 0,
      lastReadDate: null,
      readDates: [],
      frozenDates: [],
      freezeStatus: null,
    );
  }

  factory ReadingStreak.fromJson(Map<String, dynamic> json) {
    return ReadingStreak(
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastReadDate: json['last_read_date'] != null
          ? DateTime.parse(json['last_read_date'] as String)
          : null,
      readDates: (json['read_dates'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          [],
      frozenDates: (json['frozen_dates'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          [],
      freezeStatus: json['freeze_status'] != null
          ? StreakFreezeStatus.fromJson(json['freeze_status'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_read_date': lastReadDate?.toIso8601String(),
      'read_dates': readDates.map((e) => e.toIso8601String()).toList(),
      'frozen_dates': frozenDates.map((e) => e.toIso8601String()).toList(),
    };
  }

  /// Vérifie si le streak est toujours actif (lecture hier ou aujourd'hui, ou jour frozen)
  bool get isActive {
    if (currentStreak == 0) return false;
    if (lastReadDate == null && frozenDates.isEmpty) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Vérifier si hier est un jour frozen
    final yesterdayIsFrozen = frozenDates.any((d) =>
      DateTime(d.year, d.month, d.day) == yesterday
    );

    if (yesterdayIsFrozen) return true;

    if (lastReadDate == null) return false;

    final lastRead = DateTime(
      lastReadDate!.year,
      lastReadDate!.month,
      lastReadDate!.day,
    );

    return lastRead == today || lastRead == yesterday;
  }

  /// Vérifie si un jour spécifique est frozen
  bool isDayFrozen(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return frozenDates.any((d) =>
      DateTime(d.year, d.month, d.day) == normalizedDate
    );
  }

  /// Indique si le streak est en danger (pas de lecture aujourd'hui et freeze disponible)
  bool get isAtRisk {
    if (currentStreak == 0) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastReadDate == null) return true;

    final lastRead = DateTime(
      lastReadDate!.year,
      lastReadDate!.month,
      lastReadDate!.day,
    );

    // Si la dernière lecture n'est pas aujourd'hui, le streak est en danger
    return lastRead != today;
  }

  /// Retourne le badge de streak le plus élevé débloqué
  StreakBadgeLevel? get highestBadge {
    if (currentStreak >= 30) return StreakBadgeLevel.month;
    if (currentStreak >= 14) return StreakBadgeLevel.twoWeeks;
    if (currentStreak >= 7) return StreakBadgeLevel.week;
    if (currentStreak >= 3) return StreakBadgeLevel.threeDays;
    if (currentStreak >= 1) return StreakBadgeLevel.oneDay;
    return null;
  }

  /// Retourne tous les badges de streak débloqués
  List<StreakBadgeLevel> get unlockedBadges {
    final badges = <StreakBadgeLevel>[];
    if (currentStreak >= 1) badges.add(StreakBadgeLevel.oneDay);
    if (currentStreak >= 3) badges.add(StreakBadgeLevel.threeDays);
    if (currentStreak >= 7) badges.add(StreakBadgeLevel.week);
    if (currentStreak >= 14) badges.add(StreakBadgeLevel.twoWeeks);
    if (currentStreak >= 30) badges.add(StreakBadgeLevel.month);
    return badges;
  }

  /// Message de motivation basé sur le streak actuel
  String get motivationMessage {
    if (currentStreak == 0) {
      return "Commencez votre streak aujourd'hui!";
    } else if (currentStreak == 1) {
      return "Premier jour de lecture! Continuez!";
    } else if (currentStreak < 3) {
      return "Vous êtes lancé! $currentStreak jours d'affilée!";
    } else if (currentStreak < 7) {
      return "Excellent! $currentStreak jours consécutifs!";
    } else if (currentStreak < 14) {
      return "Incroyable! $currentStreak jours de lecture!";
    } else if (currentStreak < 30) {
      return "Fantastique! $currentStreak jours d'affilée!";
    } else {
      return "Légendaire! $currentStreak jours consécutifs!";
    }
  }

  /// Copie avec modifications
  ReadingStreak copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastReadDate,
    List<DateTime>? readDates,
    List<DateTime>? frozenDates,
    StreakFreezeStatus? freezeStatus,
  }) {
    return ReadingStreak(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      readDates: readDates ?? this.readDates,
      frozenDates: frozenDates ?? this.frozenDates,
      freezeStatus: freezeStatus ?? this.freezeStatus,
    );
  }
}

/// Niveaux de badges pour les streaks
enum StreakBadgeLevel {
  oneDay(1, 'Premier Jour', '📖', '#FFB74D'),
  threeDays(3, '3 Jours', '🔥', '#FF9800'),
  week(7, 'Une Semaine', '⭐', '#FFC107'),
  twoWeeks(14, '2 Semaines', '💎', '#FF5722'),
  month(30, 'Un Mois', '👑', '#9C27B0');

  final int days;
  final String name;
  final String icon;
  final String color;

  const StreakBadgeLevel(this.days, this.name, this.icon, this.color);

  String get description {
    switch (this) {
      case StreakBadgeLevel.oneDay:
        return 'Lire 1 jour';
      case StreakBadgeLevel.threeDays:
        return 'Lire 3 jours d\'affilée';
      case StreakBadgeLevel.week:
        return 'Lire 7 jours consécutifs';
      case StreakBadgeLevel.twoWeeks:
        return 'Lire 14 jours consécutifs';
      case StreakBadgeLevel.month:
        return 'Lire 30 jours d\'affilée';
    }
  }

  String get badgeId {
    switch (this) {
      case StreakBadgeLevel.oneDay:
        return 'streak_1_day';
      case StreakBadgeLevel.threeDays:
        return 'streak_3_days';
      case StreakBadgeLevel.week:
        return 'streak_7_days';
      case StreakBadgeLevel.twoWeeks:
        return 'streak_14_days';
      case StreakBadgeLevel.month:
        return 'streak_30_days';
    }
  }
}

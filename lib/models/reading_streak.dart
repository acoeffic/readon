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
    for (final level in StreakBadgeLevel.values.reversed) {
      if (currentStreak >= level.days) return level;
    }
    return null;
  }

  /// Retourne tous les badges de streak débloqués
  List<StreakBadgeLevel> get unlockedBadges {
    return StreakBadgeLevel.values
        .where((level) => currentStreak >= level.days)
        .toList();
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
  threeDays(3, 'Premier Pas', '👣', '#FFB74D', false),
  week(7, 'Une Semaine', '📅', '#FF9800', false),
  twoWeeks(14, 'Deux Semaines', '🔥', '#FFC107', false),
  month(30, 'Un Mois', '🌟', '#FF5722', false),
  twoMonths(60, 'Incassable', '💎', '#9C27B0', false),
  // Premium
  quarter(90, 'Trimestre Parfait', '🔥', '#FFD700', true),
  halfYear(180, 'Semi-Annuel', '💎', '#FFC107', true),
  year(365, 'Année Complète', '👑', '#FF9800', true),
  legendary(500, 'Streak Légendaire', '🏆', '#E91E63', true);

  final int days;
  final String name;
  final String icon;
  final String color;
  final bool isPremium;

  const StreakBadgeLevel(this.days, this.name, this.icon, this.color, this.isPremium);

  String get description => 'Streak de $days jours';

  String get badgeId => 'streak_${days}_days';
}

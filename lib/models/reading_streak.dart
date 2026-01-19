// lib/models/reading_streak.dart
// Modèle pour représenter les streaks de lecture (jours consécutifs)

class ReadingStreak {
  final int currentStreak;      // Nombre de jours consécutifs actuels
  final int longestStreak;      // Record de jours consécutifs
  final DateTime? lastReadDate; // Dernière date de lecture
  final List<DateTime> readDates; // Historique des dates de lecture

  ReadingStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastReadDate,
    required this.readDates,
  });

  factory ReadingStreak.empty() {
    return ReadingStreak(
      currentStreak: 0,
      longestStreak: 0,
      lastReadDate: null,
      readDates: [],
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_read_date': lastReadDate?.toIso8601String(),
      'read_dates': readDates.map((e) => e.toIso8601String()).toList(),
    };
  }

  /// Vérifie si le streak est toujours actif (lecture hier ou aujourd'hui)
  bool get isActive {
    if (lastReadDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastRead = DateTime(
      lastReadDate!.year,
      lastReadDate!.month,
      lastReadDate!.day,
    );

    return lastRead == today || lastRead == yesterday;
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
  }) {
    return ReadingStreak(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      readDates: readDates ?? this.readDates,
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

// lib/models/reading_flow.dart
// Modèle pour représenter les flows de lecture (jours consécutifs)

import 'flow_freeze.dart';

class ReadingFlow {
  final int currentFlow;      // Nombre de jours consécutifs actuels
  final int longestFlow;      // Record de jours consécutifs
  final DateTime? lastReadDate; // Dernière date de lecture
  final List<DateTime> readDates; // Historique des dates de lecture
  final List<DateTime> frozenDates; // Dates protégées par un freeze
  final FlowFreezeStatus? freezeStatus; // Statut du freeze

  ReadingFlow({
    required this.currentFlow,
    required this.longestFlow,
    this.lastReadDate,
    required this.readDates,
    this.frozenDates = const [],
    this.freezeStatus,
  });

  factory ReadingFlow.empty() {
    return ReadingFlow(
      currentFlow: 0,
      longestFlow: 0,
      lastReadDate: null,
      readDates: [],
      frozenDates: [],
      freezeStatus: null,
    );
  }

  factory ReadingFlow.fromJson(Map<String, dynamic> json) {
    return ReadingFlow(
      currentFlow: json['current_streak'] as int? ?? 0,
      longestFlow: json['longest_streak'] as int? ?? 0,
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
          ? FlowFreezeStatus.fromJson(json['freeze_status'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentFlow,
      'longest_streak': longestFlow,
      'last_read_date': lastReadDate?.toIso8601String(),
      'read_dates': readDates.map((e) => e.toIso8601String()).toList(),
      'frozen_dates': frozenDates.map((e) => e.toIso8601String()).toList(),
      'freeze_status': freezeStatus?.toJson(),
    };
  }

  /// Vérifie si le flow est toujours actif (lecture hier ou aujourd'hui, ou jour frozen)
  bool get isActive {
    if (currentFlow == 0) return false;
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

  /// Indique si le flow est en danger (pas de lecture aujourd'hui et freeze disponible)
  bool get isAtRisk {
    if (currentFlow == 0) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastReadDate == null) return true;

    final lastRead = DateTime(
      lastReadDate!.year,
      lastReadDate!.month,
      lastReadDate!.day,
    );

    // Si la dernière lecture n'est pas aujourd'hui, le flow est en danger
    return lastRead != today;
  }

  /// Retourne le badge de flow le plus élevé débloqué
  FlowBadgeLevel? get highestBadge {
    for (final level in FlowBadgeLevel.values.reversed) {
      if (currentFlow >= level.days) return level;
    }
    return null;
  }

  /// Retourne tous les badges de flow débloqués
  List<FlowBadgeLevel> get unlockedBadges {
    return FlowBadgeLevel.values
        .where((level) => currentFlow >= level.days)
        .toList();
  }

  /// Message de motivation basé sur le flow actuel
  String get motivationMessage {
    if (currentFlow == 0) {
      return "Commencez votre flow aujourd'hui!";
    } else if (currentFlow == 1) {
      return "Premier jour de lecture! Continuez!";
    } else if (currentFlow < 3) {
      return "Vous êtes lancé! $currentFlow jours d'affilée!";
    } else if (currentFlow < 7) {
      return "Excellent! $currentFlow jours consécutifs!";
    } else if (currentFlow < 14) {
      return "Incroyable! $currentFlow jours de lecture!";
    } else if (currentFlow < 30) {
      return "Fantastique! $currentFlow jours d'affilée!";
    } else {
      return "Légendaire! $currentFlow jours consécutifs!";
    }
  }

  /// Copie avec modifications
  ReadingFlow copyWith({
    int? currentFlow,
    int? longestFlow,
    DateTime? lastReadDate,
    List<DateTime>? readDates,
    List<DateTime>? frozenDates,
    FlowFreezeStatus? freezeStatus,
  }) {
    return ReadingFlow(
      currentFlow: currentFlow ?? this.currentFlow,
      longestFlow: longestFlow ?? this.longestFlow,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      readDates: readDates ?? this.readDates,
      frozenDates: frozenDates ?? this.frozenDates,
      freezeStatus: freezeStatus ?? this.freezeStatus,
    );
  }
}

/// Niveaux de badges pour les flows
enum FlowBadgeLevel {
  threeDays(3, 'Premier Pas', '👣', '#FFB74D', false),
  week(7, 'Une Semaine', '📅', '#FF9800', false),
  twoWeeks(14, 'Deux Semaines', '🔥', '#FFC107', false),
  month(30, 'Un Mois', '🌟', '#FF5722', false),
  twoMonths(60, 'Incassable', '💎', '#9C27B0', false),
  // Premium
  quarter(90, 'Trimestre Parfait', '🔥', '#FFD700', true),
  halfYear(180, 'Semi-Annuel', '💎', '#FFC107', true),
  year(365, 'Année Complète', '👑', '#FF9800', true),
  legendary(500, 'Flow Légendaire', '🏆', '#E91E63', true);

  final int days;
  final String name;
  final String icon;
  final String color;
  final bool isPremium;

  const FlowBadgeLevel(this.days, this.name, this.icon, this.color, this.isPremium);

  String get description => 'Flow de $days jours';

  String get badgeId => 'streak_${days}_days';
}

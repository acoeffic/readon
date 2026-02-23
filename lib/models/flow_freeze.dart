// lib/models/flow_freeze.dart
// Modele pour la protection de flow (freeze) - V2 free/premium

class FlowFreezeStatus {
  final bool isPremium;
  final bool canFreeze;              // Quota dispo ET limite consécutive non atteinte
  final bool canManualFreeze;        // true uniquement pour premium
  final int autoFreezesThisMonth;    // Auto-freezes utilisés ce mois
  final int autoFreezeLimit;         // -1 = illimité (premium), 2 = gratuit
  final int autoFreezesRemaining;    // -1 = illimité
  final int consecutiveFrozenDays;   // Jours consécutifs frozen actuels
  final int maxConsecutive;          // 1 gratuit, 2 premium
  final DateTime? lastFreezeDate;    // Date du dernier freeze utilisé
  final DateTime monthStart;         // Début du mois courant

  FlowFreezeStatus({
    required this.isPremium,
    required this.canFreeze,
    required this.canManualFreeze,
    required this.autoFreezesThisMonth,
    required this.autoFreezeLimit,
    required this.autoFreezesRemaining,
    required this.consecutiveFrozenDays,
    required this.maxConsecutive,
    this.lastFreezeDate,
    required this.monthStart,
  });

  factory FlowFreezeStatus.empty() {
    final now = DateTime.now();
    return FlowFreezeStatus(
      isPremium: false,
      canFreeze: true,
      canManualFreeze: false,
      autoFreezesThisMonth: 0,
      autoFreezeLimit: 2,
      autoFreezesRemaining: 2,
      consecutiveFrozenDays: 0,
      maxConsecutive: 1,
      lastFreezeDate: null,
      monthStart: DateTime(now.year, now.month, 1),
    );
  }

  factory FlowFreezeStatus.fromJson(Map<String, dynamic> json) {
    return FlowFreezeStatus(
      isPremium: json['is_premium'] as bool? ?? false,
      canFreeze: json['can_freeze'] as bool? ?? false,
      canManualFreeze: json['can_manual_freeze'] as bool? ?? false,
      autoFreezesThisMonth: json['auto_freezes_this_month'] as int? ?? 0,
      autoFreezeLimit: json['auto_freeze_limit'] as int? ?? 2,
      autoFreezesRemaining: json['auto_freezes_remaining'] as int? ?? 0,
      consecutiveFrozenDays: json['consecutive_frozen_days'] as int? ?? 0,
      maxConsecutive: json['max_consecutive'] as int? ?? 1,
      lastFreezeDate: json['last_freeze_date'] != null
          ? DateTime.parse(json['last_freeze_date'] as String)
          : null,
      monthStart: DateTime.parse(json['month_start'] as String),
    );
  }

  /// Auto-freezes illimités ?
  bool get isUnlimited => autoFreezeLimit == -1;

  /// Jours restants avant le renouvellement mensuel
  int get daysUntilRenewal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
    return nextMonth.difference(today).inDays;
  }

  /// Message de statut pour l'UI
  String get statusMessage {
    if (isPremium) {
      if (canFreeze) {
        return 'Auto-freeze illimité';
      } else {
        return 'Limite de $maxConsecutive jours consécutifs atteinte';
      }
    } else {
      if (autoFreezesRemaining > 0 && canFreeze) {
        return '$autoFreezesRemaining auto-freeze(s) restant(s) ce mois';
      } else if (autoFreezesRemaining <= 0) {
        return 'Auto-freezes épuisés (renouvellement dans $daysUntilRenewal j)';
      } else {
        return 'Limite de jours consécutifs atteinte';
      }
    }
  }
}

class FreezeResult {
  final bool success;
  final String? error;
  final String message;
  final DateTime? frozenDate;

  FreezeResult({
    required this.success,
    this.error,
    required this.message,
    this.frozenDate,
  });

  factory FreezeResult.fromJson(Map<String, dynamic> json) {
    return FreezeResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      message: json['message'] as String? ?? '',
      frozenDate: json['frozen_date'] != null
          ? DateTime.parse(json['frozen_date'] as String)
          : null,
    );
  }
}

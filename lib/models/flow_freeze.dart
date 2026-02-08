// lib/models/flow_freeze.dart
// Modele pour la protection de flow (freeze)

class FlowFreezeStatus {
  final bool freezeAvailable;      // Un freeze est disponible cette semaine
  final bool freezeUsedThisWeek;   // Un freeze a été utilisé cette semaine
  final DateTime? lastFreezeDate;  // Date du dernier freeze utilisé
  final DateTime weekStart;        // Début de la semaine courante
  final DateTime weekEnd;          // Fin de la semaine courante

  FlowFreezeStatus({
    required this.freezeAvailable,
    required this.freezeUsedThisWeek,
    this.lastFreezeDate,
    required this.weekStart,
    required this.weekEnd,
  });

  factory FlowFreezeStatus.empty() {
    final now = DateTime.now();
    // Calculer le lundi de cette semaine
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return FlowFreezeStatus(
      freezeAvailable: true,
      freezeUsedThisWeek: false,
      lastFreezeDate: null,
      weekStart: weekStartDate,
      weekEnd: weekStartDate.add(const Duration(days: 6)),
    );
  }

  factory FlowFreezeStatus.fromJson(Map<String, dynamic> json) {
    return FlowFreezeStatus(
      freezeAvailable: json['freeze_available'] as bool? ?? true,
      freezeUsedThisWeek: json['freeze_used_this_week'] as bool? ?? false,
      lastFreezeDate: json['last_freeze_date'] != null
          ? DateTime.parse(json['last_freeze_date'] as String)
          : null,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
    );
  }

  /// Jours restants avant le renouvellement du freeze
  int get daysUntilRenewal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return weekEnd.difference(today).inDays + 1;
  }

  /// Message de statut pour l'UI
  String get statusMessage {
    if (freezeAvailable) {
      return 'Freeze disponible';
    } else {
      return 'Freeze utilisé (renouvellement dans $daysUntilRenewal j)';
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

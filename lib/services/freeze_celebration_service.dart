// lib/services/freeze_celebration_service.dart
// Détecte les auto-freezes appliqués silencieusement par le cron serveur
// (auto_freeze_all_users) pour les célébrer à l'ouverture de l'app.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FreezeCelebrationService {
  static const String _seenKey = 'auto_freeze_seen_dates';
  static const int _lookbackDays = 7;
  static const int _maxSeenEntries = 60;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Retourne les dates d'auto-freeze récentes pas encore vues par
  /// l'utilisateur courant, et les marque comme vues.
  Future<List<DateTime>> consumeUnseenAutoFreezes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final since =
          DateTime.now().subtract(const Duration(days: _lookbackDays));
      final sinceStr = since.toIso8601String().split('T')[0];

      final rows = await _supabase
          .from('streak_freezes')
          .select('frozen_date')
          .eq('user_id', userId)
          .eq('is_auto', true)
          .gte('frozen_date', sinceStr);

      if ((rows as List).isEmpty) return [];

      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getStringList(_seenKey) ?? []).toSet();

      final unseen = <DateTime>[];
      for (final row in rows) {
        final dateStr = row['frozen_date'] as String?;
        if (dateStr == null) continue;
        final key = '$userId:$dateStr';
        if (seen.contains(key)) continue;
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          unseen.add(parsed);
          seen.add(key);
        }
      }

      if (unseen.isNotEmpty) {
        // Borner la liste pour éviter une croissance infinie des prefs.
        final pruned = seen.toList()..sort();
        await prefs.setStringList(
          _seenKey,
          pruned.length > _maxSeenEntries
              ? pruned.sublist(pruned.length - _maxSeenEntries)
              : pruned,
        );
      }

      return unseen;
    } catch (e) {
      debugPrint('Erreur consumeUnseenAutoFreezes: $e');
      return [];
    }
  }
}

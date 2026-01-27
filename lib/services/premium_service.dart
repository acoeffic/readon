// lib/services/premium_service.dart
// Service pour gérer le statut premium de l'utilisateur

import 'package:supabase_flutter/supabase_flutter.dart';

class PremiumService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache local du statut premium
  bool? _cachedPremiumStatus;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  /// Vérifier si l'utilisateur est premium (avec cache)
  Future<bool> isPremium() async {
    if (_cachedPremiumStatus != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return _cachedPremiumStatus!;
      }
    }

    try {
      final result = await _supabase.rpc('check_premium_status');
      _cachedPremiumStatus = result['is_premium'] as bool? ?? false;
      _cacheTimestamp = DateTime.now();
      return _cachedPremiumStatus!;
    } catch (e) {
      print('Erreur isPremium: $e');
      return false;
    }
  }

  /// Invalider le cache (après un achat par exemple)
  void invalidateCache() {
    _cachedPremiumStatus = null;
    _cacheTimestamp = null;
  }
}

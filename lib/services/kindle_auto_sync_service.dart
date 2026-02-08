import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KindleAutoSyncService {
  static const String _lastSyncKey = 'kindle_last_sync';
  static const String _autoSyncEnabledKey = 'kindle_auto_sync_enabled';
  static const Duration _syncInterval = Duration(hours: 24);

  /// Vérifie si l'auto-sync doit se déclencher
  Future<bool> shouldAutoSync({required bool isPremium}) async {
    if (!isPremium) return false;

    final prefs = await SharedPreferences.getInstance();

    // Kindle jamais connecté
    final lastSync = prefs.getString(_lastSyncKey);
    if (lastSync == null) return false;

    // Auto-sync désactivé par l'utilisateur
    final enabled = prefs.getBool(_autoSyncEnabledKey) ?? true;
    if (!enabled) return false;

    // Dernier sync trop récent (< 24h)
    try {
      final lastSyncDate = DateTime.parse(lastSync);
      final elapsed = DateTime.now().difference(lastSyncDate);
      if (elapsed < _syncInterval) return false;
    } catch (e) {
      debugPrint('KindleAutoSync: erreur parsing lastSync: $e');
      return false;
    }

    return true;
  }

  /// Vérifie si l'auto-sync est activé dans les préférences
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncEnabledKey) ?? true;
  }

  /// Active/désactive l'auto-sync
  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, enabled);
  }

  /// Vérifie si le Kindle a déjà été connecté
  Future<bool> isKindleConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey) != null;
  }
}

// lib/services/app_update_service.dart
//
// Rappel doux de mise à jour : compare la version installée (package_info_plus)
// à la version publiée en base (table `app_versions`, lue via la RPC
// `get_app_version_info`). Si l'app est en retard, une bannière dismissible
// propose d'ouvrir la fiche store (voir widgets/update_available_banner.dart).
//
// Garde-fou : une fois dismissée pour une version donnée, la bannière ne
// réapparaît pas tant qu'une version plus récente n'est pas publiée.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String storeUrl;

  const AppUpdateInfo({required this.latestVersion, required this.storeUrl});
}

class AppUpdateService {
  static const _dismissedVersionKey = 'app_update_dismissed_version';

  /// Retourne les infos de mise à jour si une version plus récente que
  /// l'app installée est publiée ET que l'utilisateur n'a pas déjà dismissé
  /// cette version précise. Retourne `null` sinon (y compris en cas
  /// d'erreur réseau — jamais bloquant).
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : null;
      if (platform == null) return null; // web/desktop : pas de store

      final info = await PackageInfo.fromPlatform();
      final response = await Supabase.instance.client
          .rpc('get_app_version_info', params: {'p_platform': platform})
          .maybeSingle();
      if (response == null) return null;

      final latestVersion = response['latest_version'] as String?;
      final storeUrl = response['store_url'] as String?;
      if (latestVersion == null || storeUrl == null) return null;

      if (_compareVersions(info.version, latestVersion) >= 0) {
        return null; // déjà à jour (ou en avance — build dev/TestFlight)
      }

      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_dismissedVersionKey);
      if (dismissed == latestVersion) return null;

      return AppUpdateInfo(latestVersion: latestVersion, storeUrl: storeUrl);
    } catch (e) {
      debugPrint('AppUpdateService: $e');
      return null;
    }
  }

  /// À appeler quand l'utilisateur ferme la bannière : ne plus la
  /// remontrer pour cette version précise.
  static Future<void> dismiss(String latestVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, latestVersion);
    } catch (_) {
      // Non critique.
    }
  }

  /// Compare deux versions "1.2.3" (parties non numériques ignorées).
  /// Retourne <0 si [a] < [b], 0 si égales, >0 si [a] > [b].
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partsB = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final length = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < length; i++) {
      final vA = i < partsA.length ? partsA[i] : 0;
      final vB = i < partsB.length ? partsB[i] : 0;
      if (vA != vB) return vA - vB;
    }
    return 0;
  }
}

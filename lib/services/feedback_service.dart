// lib/services/feedback_service.dart
//
// Envoi des feedbacks in-app vers la table `app_feedback` (migration
// 20260810_app_feedback.sql). La table est write-only côté client :
// INSERT de ses propres lignes uniquement, jamais de SELECT (ne pas
// chaîner `.select()` après l'insert). Un trigger DB notifie l'admin
// par email à chaque nouveau feedback.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_service.dart';

/// Résultat d'un appel `submit`.
enum FeedbackResult {
  success,
  notAuthenticated,
  error,
}

class FeedbackService {
  FeedbackService._();
  static final FeedbackService _instance = FeedbackService._();
  factory FeedbackService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Soumet un feedback libre. Contexte (version, plateforme, locale)
  /// attaché automatiquement — best-effort, jamais bloquant.
  Future<FeedbackResult> submit(String message) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return FeedbackResult.notAuthenticated;

    final trimmed = message.trim();
    if (trimmed.isEmpty) return FeedbackResult.error;

    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('FeedbackService: PackageInfo indisponible: $e');
    }

    try {
      await _supabase.from('app_feedback').insert({
        'user_id': userId,
        'message': trimmed,
        if (appVersion != null) 'app_version': appVersion,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
      });

      unawaited(AnalyticsService().track('feedback_submitted'));

      return FeedbackResult.success;
    } catch (e) {
      debugPrint('FeedbackService.submit error: $e');
      return FeedbackResult.error;
    }
  }
}

// lib/services/live_activity_service.dart
//
// Pilote la Live Activity iOS (écran verrouillage + Dynamic Island) pour une
// session de lecture en cours. Repose sur un MethodChannel custom défini côté
// natif dans ios/Runner/AppDelegate.swift.
//
// Sur Android ou iOS < 16.1, toutes les méthodes sont des no-op silencieux.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

typedef LiveActivityCommandHandler = Future<void> Function(
  String command,
  String sessionId,
);

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  static const MethodChannel _channel =
      MethodChannel('fr.lexday.app/reading_live_activity');

  Timer? _pollTimer;
  LiveActivityCommandHandler? _onCommand;

  // Cache couverture pour éviter de re-télécharger à chaque start.
  String? _cachedCoverUrl;
  String? _cachedCoverBase64;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Indique si les Live Activities sont disponibles et autorisées.
  Future<bool> isAvailable() async {
    if (!_isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isAvailable');
      return res ?? false;
    } catch (e) {
      debugPrint('LiveActivity.isAvailable error: $e');
      return false;
    }
  }

  /// Démarre une Live Activity pour une session de lecture.
  Future<void> start({
    required String sessionId,
    required String bookTitle,
    String bookAuthor = '',
    String? coverUrl,
    int accumulatedSeconds = 0,
    bool isPaused = false,
  }) async {
    if (!_isIOS) return;
    try {
      final coverBase64 = await _resolveCover(coverUrl);
      await _channel.invokeMethod('start', {
        'sessionId': sessionId,
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor,
        'coverBase64': coverBase64,
        'accumulatedSeconds': accumulatedSeconds,
        'isPaused': isPaused,
      });
    } catch (e) {
      debugPrint('LiveActivity.start error: $e');
    }
  }

  /// Met à jour l'état de la Live Activity (pause / reprise / nouveau timer).
  Future<void> update({
    required String sessionId,
    required int accumulatedSeconds,
    required bool isPaused,
  }) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('update', {
        'sessionId': sessionId,
        'accumulatedSeconds': accumulatedSeconds,
        'isPaused': isPaused,
      });
    } catch (e) {
      debugPrint('LiveActivity.update error: $e');
    }
  }

  /// Termine la Live Activity.
  Future<void> end({required String sessionId}) async {
    stopCommandPolling();
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('end', {'sessionId': sessionId});
    } catch (e) {
      debugPrint('LiveActivity.end error: $e');
    }
  }

  /// Démarre un polling léger pour récupérer les commandes pause/resume
  /// déclenchées depuis la Live Activity (App Intents → App Group).
  /// À appeler après `start()`. À stopper via `stopCommandPolling()` ou `end()`.
  void startCommandPolling({
    required LiveActivityCommandHandler onCommand,
    Duration interval = const Duration(seconds: 2),
  }) {
    if (!_isIOS) return;
    _onCommand = onCommand;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _pollOnce());
  }

  void stopCommandPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onCommand = null;
  }

  Future<void> _pollOnce() async {
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('pollPendingCommand');
      if (res == null) return;
      final command = res['command'] as String?;
      final sessionId = res['sessionId'] as String?;
      if (command == null || sessionId == null) return;
      await _onCommand?.call(command, sessionId);
    } catch (e) {
      debugPrint('LiveActivity.poll error: $e');
    }
  }

  // -------- Cover helpers --------

  // User-Agent type Safari iOS : Google Books / Amazon / OpenLibrary refusent
  // souvent les requêtes sans UA "navigateur" (403 ou 0 byte). C'est le même
  // UA que celui utilisé par `CachedBookCover` côté app, ce qui explique
  // qu'une cover s'affiche en app mais échoue sur la Live Activity quand
  // on faisait un `http.get` brut.
  static const _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  };

  Future<String> _resolveCover(String? url) async {
    if (url == null || url.isEmpty) {
      debugPrint('LiveActivity._resolveCover: url null/empty');
      return '';
    }
    if (_cachedCoverUrl == url && _cachedCoverBase64 != null) {
      return _cachedCoverBase64!;
    }
    try {
      final res = await http
          .get(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('LiveActivity._resolveCover: HTTP ${res.statusCode} for $url');
        return '';
      }
      if (res.bodyBytes.isEmpty) {
        debugPrint('LiveActivity._resolveCover: empty body for $url');
        return '';
      }
      final encoded = base64Encode(res.bodyBytes);
      _cachedCoverUrl = url;
      _cachedCoverBase64 = encoded;
      debugPrint('LiveActivity._resolveCover: ${res.bodyBytes.length} bytes from $url');
      return encoded;
    } catch (e) {
      debugPrint('LiveActivity._resolveCover error: $e');
      return '';
    }
  }
}

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

import '../widgets/cached_book_cover.dart';

typedef LiveActivityCommandHandler = Future<void> Function(
  String command,
  String sessionId,
);

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal() {
    // Les commandes Pause/Reprendre des boutons de la Live Activity sont
    // poussées par le natif (AppDelegate) dès que l'App Intent s'exécute —
    // y compris quand l'app est en arrière-plan (le tap réveille le process).
    // Le polling ci-dessous reste en fallback (app tuée / engine pas prêt).
    if (_isIOS) {
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  static const MethodChannel _channel =
      MethodChannel('fr.lexday.app/reading_live_activity');

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onLiveActivityCommand') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final command = args['command'] as String?;
      final sessionId = args['sessionId'] as String?;
      if (command != null && sessionId != null) {
        await _onCommand?.call(command, sessionId);
      }
    }
    return null;
  }

  Timer? _pollTimer;
  LiveActivityCommandHandler? _onCommand;

  // Cache couverture pour éviter de re-télécharger à chaque start.
  String? _cachedCoverUrl;
  String? _cachedCoverBase64;

  // --- Retry de couverture en cours de session ---
  // Si la résolution échoue au start() (réseau lent, timeout de la chaîne,
  // CDN qui sert un placeholder rejeté), on mémorise de quoi retenter :
  // au prochain update() (pause/reprise), on relance la résolution et on
  // pousse l'image — la Live Activity la lit au re-render suivant.
  String? _coverSessionId;
  bool _coverDelivered = false;
  List<String> _retryCoverUrls = const [];
  Map<String, String?>? _retryBookInfo;
  bool _retryInFlight = false;

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
  ///
  /// [coverUrls] : liste ordonnée de candidates (typiquement la chaîne
  /// validée par `CachedBookCover.resolveCoverUrls`). La première qui
  /// télécharge une vraie image (pas un placeholder) est utilisée.
  ///
  /// [bookInfo] (optionnel) : identité du livre (imageUrl/isbn/googleId/
  /// title/author) — permet de RE-résoudre la chaîne complète plus tard si
  /// aucune candidate n'a abouti au démarrage (voir [update]).
  Future<void> start({
    required String sessionId,
    required String bookTitle,
    String bookAuthor = '',
    List<String> coverUrls = const [],
    Map<String, String?>? bookInfo,
    int accumulatedSeconds = 0,
    bool isPaused = false,
  }) async {
    if (!_isIOS) return;
    try {
      final coverBase64 = await _resolveCover(coverUrls);
      _coverSessionId = sessionId;
      _coverDelivered = coverBase64.isNotEmpty;
      _retryCoverUrls = coverUrls;
      _retryBookInfo = bookInfo;
      _retryInFlight = false;
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
  ///
  /// Si la couverture n'a pas pu être livrée au démarrage, un retry part en
  /// arrière-plan (sans retarder l'update d'état — le bouton Pause doit
  /// rester instantané) ; quand une image aboutit, elle est poussée via
  /// `setCover`, qui force un re-render de la Live Activity.
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
    unawaited(_retryCoverThenPush(sessionId));
  }

  /// Retry en arrière-plan : résout, puis pousse la couverture au natif.
  Future<void> _retryCoverThenPush(String sessionId) async {
    final coverBase64 = await _retryCoverIfNeeded(sessionId);
    if (coverBase64 == null || coverBase64.isEmpty) return;
    try {
      await _channel.invokeMethod('setCover', {
        'sessionId': sessionId,
        'coverBase64': coverBase64,
      });
    } catch (e) {
      debugPrint('LiveActivity.setCover error: $e');
    }
  }

  /// Retente la résolution de couverture pour [sessionId] si elle a échoué
  /// au démarrage. Retourne le base64 à pousser, ou null si rien à faire.
  Future<String?> _retryCoverIfNeeded(String sessionId) async {
    if (_coverDelivered ||
        _coverSessionId != sessionId ||
        _retryInFlight) {
      return null;
    }
    _retryInFlight = true;
    try {
      // 1) Les candidates connues (si la chaîne avait abouti mais que tous
      //    les téléchargements avaient échoué / été rejetés).
      var coverBase64 = await _resolveCover(_retryCoverUrls);

      // 2) Sinon, re-résout la chaîne complète en ignorant le cache (qui a
      //    pu mémoriser une liste vide après un timeout hors-ligne).
      final info = _retryBookInfo;
      if (coverBase64.isEmpty && info != null) {
        try {
          final urls = await CachedBookCover.resolveCoverUrls(
            imageUrl: info['imageUrl'],
            isbn: info['isbn'],
            googleId: info['googleId'],
            title: info['title'],
            author: info['author'],
            refresh: true,
          ).timeout(const Duration(seconds: 8));
          if (urls.isNotEmpty) {
            _retryCoverUrls = urls;
            coverBase64 = await _resolveCover(urls);
          }
        } catch (_) {}
      }

      if (coverBase64.isNotEmpty) {
        _coverDelivered = true;
        debugPrint('LiveActivity: couverture récupérée au retry');
        return coverBase64;
      }
      return null;
    } finally {
      _retryInFlight = false;
    }
  }

  /// Termine la Live Activity.
  Future<void> end({required String sessionId}) async {
    stopCommandPolling();
    if (_coverSessionId == sessionId) {
      _coverSessionId = null;
      _coverDelivered = false;
      _retryCoverUrls = const [];
      _retryBookInfo = null;
    }
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

  /// Essaie chaque URL dans l'ordre et retourne le base64 de la première
  /// vraie couverture. Rejette les images placeholder (GIF 1×1 Amazon,
  /// PNG gris Google Books) qui sinon s'affichent comme un rectangle gris
  /// sur la Live Activity.
  Future<String> _resolveCover(List<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty) continue;
      if (_cachedCoverUrl == url && _cachedCoverBase64 != null) {
        return _cachedCoverBase64!;
      }
      try {
        final res = await http
            .get(Uri.parse(url), headers: _browserHeaders)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) {
          debugPrint('LiveActivity._resolveCover: HTTP ${res.statusCode} for $url');
          continue;
        }
        if (!await CachedBookCover.looksLikeRealCoverPixels(url, res.bodyBytes)) {
          debugPrint(
            'LiveActivity._resolveCover: placeholder rejeté '
            '(${res.bodyBytes.length} bytes) for $url',
          );
          continue;
        }
        final encoded = base64Encode(res.bodyBytes);
        _cachedCoverUrl = url;
        _cachedCoverBase64 = encoded;
        debugPrint('LiveActivity._resolveCover: ${res.bodyBytes.length} bytes from $url');
        return encoded;
      } catch (e) {
        debugPrint('LiveActivity._resolveCover error for $url: $e');
      }
    }
    debugPrint('LiveActivity._resolveCover: aucune couverture valide (${urls.length} candidates)');
    return '';
  }
}

// lib/services/watch_control_service.dart
//
// Pont Flutter ↔ Apple Watch. Repose sur le MethodChannel `fr.lexday.app/watch`
// défini côté natif (ios/Runner/AppDelegate.swift + WatchConnectivityManager).
//
// Deux rôles :
//  - Pousser l'état courant (livre + stats + état de session) vers la Watch.
//  - Récupérer par polling les commandes émises depuis la Watch (start / pause /
//    resume / stop) et les appliquer via [ReadingSessionService].
//
// Sur Android ou si aucune Watch n'est appairée, toutes les méthodes sont des
// no-op silencieux.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import 'books_service.dart';
import 'reading_session_service.dart';
import 'session_pause_service.dart';
import 'watch_session_draft_service.dart';

class WatchControlService {
  static final WatchControlService _instance = WatchControlService._internal();
  factory WatchControlService() => _instance;
  WatchControlService._internal();

  static const MethodChannel _channel = MethodChannel('fr.lexday.app/watch');

  final ReadingSessionService _sessions = ReadingSessionService();
  final BooksService _books = BooksService();

  Timer? _pollTimer;
  bool _handling = false;
  bool _started = false;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Indique si une Apple Watch appairée est disponible.
  Future<bool> isSupported() async {
    if (!_isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Démarre le polling des commandes Watch. À appeler une fois au lancement.
  Future<void> start({Duration interval = const Duration(seconds: 2)}) async {
    if (!_isIOS || _started) return;
    _started = true;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _pollOnce());
    // Reflète sur la Watch les changements de session initiés depuis l'iPhone
    // (démarrage / fin / annulation / pause / reprise) sans polling lourd.
    ReadingSessionService.activeSessionsVersion.addListener(_onSessionsChanged);
    ReadingSessionService.pauseStateVersion.addListener(_onSessionsChanged);
    // Pousse l'état initial pour que la Watch ne reste pas vide au démarrage.
    await pushState();
  }

  void _onSessionsChanged() => pushState();

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
    ReadingSessionService.activeSessionsVersion
        .removeListener(_onSessionsChanged);
    ReadingSessionService.pauseStateVersion.removeListener(_onSessionsChanged);
  }

  // MARK: - iPhone → Watch

  /// Calcule l'état de session courant et le pousse vers la Watch.
  /// Le livre et les stats du jour sont lus côté natif dans l'App Group
  /// (déjà alimenté par [WidgetService]).
  Future<void> pushState() async {
    if (!_isIOS) return;
    try {
      final active = await _sessions.getAllActiveSessions();
      bool isReading = active.isNotEmpty;
      bool isPaused = false;
      String sessionId = '';

      if (isReading) {
        sessionId = active.first.id;
        isPaused = (await SessionPauseService().getPausedAt()) != null;
      }

      await _channel.invokeMethod('pushState', {
        'isReading': isReading,
        'isPaused': isPaused,
        'sessionId': sessionId,
      });
    } catch (e) {
      debugPrint('WatchControl.pushState error: $e');
    }
  }

  // MARK: - Watch → iPhone (polling des commandes)

  Future<void> _pollOnce() async {
    if (_handling) return;
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('pollCommand');
      if (res == null) return;
      final command = res['command'] as String?;
      if (command == null) return;
      _handling = true;
      await _dispatch(command);
    } catch (e) {
      debugPrint('WatchControl.poll error: $e');
    } finally {
      _handling = false;
    }
  }

  Future<void> _dispatch(String command) async {
    switch (command) {
      case 'start':
        await _handleStart();
        break;
      case 'pause':
        await _handlePauseResume(pause: true);
        break;
      case 'resume':
        await _handlePauseResume(pause: false);
        break;
      case 'stop':
        await _handleStop();
        break;
      default:
        debugPrint('WatchControl: commande inconnue "$command"');
    }
    // Reflète le nouvel état sur la Watch après chaque action.
    await pushState();
  }

  /// Lance une session pour le livre en cours, à sa dernière page connue.
  Future<void> _handleStart() async {
    final active = await _sessions.getAllActiveSessions();
    if (active.isNotEmpty) return; // déjà une session en cours

    final data = await _books.getCurrentReadingBook();
    if (data == null) return; // aucun livre en cours

    final book = data['book'] as Book;
    final currentPage = (data['current_page'] as int?) ?? 0;
    final startPage = currentPage > 0 ? currentPage : 1;

    try {
      await _sessions.startSession(
        bookId: book.id.toString(),
        manualPageNumber: startPage,
      );
    } catch (e) {
      debugPrint('WatchControl.start error: $e');
    }
  }

  Future<void> _handlePauseResume({required bool pause}) async {
    final session = await _firstActiveSession();
    if (session == null) return;
    try {
      if (pause) {
        await _sessions.pauseSession(session.id, startTime: session.startTime);
      } else {
        await _sessions.resumeSession(session.id, startTime: session.startTime);
      }
    } catch (e) {
      debugPrint('WatchControl.pauseResume error: $e');
    }
  }

  /// Termine la session active. La page de fin est la page courante du livre si
  /// elle est plus avancée que la page de départ, sinon la page de départ
  /// (la session enregistre alors uniquement le temps de lecture).
  ///
  /// La Watch ne permet pas de saisir la page de fin : la session est mémorisée
  /// dans [WatchSessionDraftService] pour proposer un rattrapage (saisie
  /// manuelle ou photo/OCR) à la prochaine ouverture de l'app iPhone.
  Future<void> _handleStop() async {
    final session = await _firstActiveSession();
    if (session == null) return;

    int endPage = session.startPage;
    String? bookTitle;
    try {
      final data = await _books.getCurrentReadingBook();
      final currentPage = (data?['current_page'] as int?) ?? 0;
      if (currentPage > endPage) endPage = currentPage;
      bookTitle = (data?['book'] as Book?)?.title;
    } catch (_) {}

    try {
      final ended = await _sessions.endSession(
        sessionId: session.id,
        manualPageNumber: endPage,
      );
      await WatchSessionDraftService().save(WatchSessionDraft(
        sessionId: ended.id,
        startPage: ended.startPage,
        endPage: ended.endPage ?? endPage,
        durationMinutes: ended.durationMinutes,
        bookTitle: bookTitle,
      ));
    } catch (e) {
      debugPrint('WatchControl.stop error: $e');
    }
  }

  Future<ReadingSession?> _firstActiveSession() async {
    final active = await _sessions.getAllActiveSessions();
    return active.isEmpty ? null : active.first;
  }
}

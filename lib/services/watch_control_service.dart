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

  /// Dernière session active connue (alimentée par chaque lecture réseau).
  /// Permet à pause / reprise / arrêt et au push d'état de répondre sans
  /// attendre Supabase. `_activeKnown` distingue « aucune session » de
  /// « pas encore lu ».
  ReadingSession? _cachedActive;
  bool _activeKnown = false;
  bool _pushing = false;
  bool _pushDirty = false;

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
    // Le natif notifie `commandReceived` dès qu'une commande Watch arrive :
    // traitement immédiat, le polling ci-dessous n'est plus qu'un filet de
    // sécurité (commande arrivée moteur Flutter éteint, notification perdue…).
    _channel.setMethodCallHandler(_onNativeCall);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _pollOnce());
    // Consomme sans attendre une éventuelle commande reçue avant le démarrage
    // du service (ex. stop envoyé depuis la Watch app iPhone fermée).
    unawaited(_pollOnce());
    // Reflète sur la Watch les changements de session initiés depuis l'iPhone
    // (démarrage / fin / annulation / pause / reprise) sans polling lourd.
    ReadingSessionService.activeSessionsVersion.addListener(_onSessionsChanged);
    ReadingSessionService.pauseStateVersion.addListener(_onPauseChanged);
    // Pousse l'état initial pour que la Watch ne reste pas vide au démarrage.
    await pushState();
  }

  // Session créée / terminée / annulée : on relit l'état réel.
  void _onSessionsChanged() {
    _activeKnown = false;
    pushState();
  }

  // Pause / reprise : seule la pause change, le cache de session suffit
  // (pas d'aller-retour réseau).
  void _onPauseChanged() => pushState();

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'commandReceived') {
      await _pollOnce();
    }
    return null;
  }

  /// Consomme immédiatement une éventuelle commande Watch en attente.
  /// Utile au retour au premier plan, avant d'inspecter l'état des sessions.
  /// Repousse aussi l'état à la Watch (stats du jour, session) : au retour au
  /// premier plan, la Watch a pu rater un push pendant que l'app était suspendue.
  Future<void> pollNow() async {
    await _pollOnce();
    await pushState();
  }

  void stop() {
    _channel.setMethodCallHandler(null);
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
    ReadingSessionService.activeSessionsVersion
        .removeListener(_onSessionsChanged);
    ReadingSessionService.pauseStateVersion.removeListener(_onPauseChanged);
  }

  // MARK: - iPhone → Watch

  /// Calcule l'état de session courant et le pousse vers la Watch.
  /// Le livre et les stats du jour sont lus côté natif dans l'App Group
  /// (déjà alimenté par [WidgetService]). Les appels rapprochés sont
  /// coalescés : un seul push en vol, rejoué une fois si besoin.
  Future<void> pushState() async {
    if (!_isIOS) return;
    if (_pushing) {
      _pushDirty = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushDirty = false;
        final session = await _activeSession();
        final isReading = session != null;
        final isPaused =
            isReading && (await SessionPauseService().getPausedAt()) != null;
        await _sendState(
          isReading: isReading,
          isPaused: isPaused,
          sessionId: session?.id ?? '',
        );
      } while (_pushDirty);
    } catch (e) {
      debugPrint('WatchControl.pushState error: $e');
    } finally {
      _pushing = false;
    }
  }

  Future<void> _sendState({
    required bool isReading,
    required bool isPaused,
    required String sessionId,
  }) {
    return _channel.invokeMethod('pushState', {
      'isReading': isReading,
      'isPaused': isPaused,
      'sessionId': sessionId,
    });
  }

  /// Session active : cache si connu, sinon lecture réseau (qui remplit le cache).
  Future<ReadingSession?> _activeSession() async {
    if (_activeKnown) return _cachedActive;
    final active = await _sessions.getAllActiveSessions();
    _cachedActive = active.isEmpty ? null : active.first;
    _activeKnown = true;
    return _cachedActive;
  }

  /// Réponse immédiate à la Watch AVANT tout travail réseau : on pousse l'état
  /// attendu après la commande (la Watch l'a déjà en optimiste ; ça évite
  /// qu'un push périmé la fasse revenir en arrière). L'état réel suit.
  Future<void> _pushOptimistic(String command) async {
    try {
      final session = _activeKnown ? _cachedActive : null;
      switch (command) {
        case 'start':
          await _sendState(
              isReading: true, isPaused: false, sessionId: session?.id ?? '');
          break;
        case 'pause':
          await _sendState(
              isReading: true, isPaused: true, sessionId: session?.id ?? '');
          break;
        case 'resume':
          await _sendState(
              isReading: true, isPaused: false, sessionId: session?.id ?? '');
          break;
        case 'stop':
          await _sendState(isReading: false, isPaused: false, sessionId: '');
          break;
      }
    } catch (_) {}
  }

  // MARK: - Watch → iPhone (polling des commandes)

  bool _repoll = false;

  /// Dépile toutes les commandes en attente (la file native peut en contenir
  /// plusieurs). Si un appel arrive pendant un traitement, on re-vide ensuite
  /// au lieu de l'ignorer.
  Future<void> _pollOnce() async {
    if (_handling) {
      _repoll = true;
      return;
    }
    _handling = true;
    try {
      do {
        _repoll = false;
        while (true) {
          final res =
              await _channel.invokeMapMethod<String, dynamic>('pollCommand');
          if (res == null) break;
          final command = res['command'] as String?;
          if (command == null) break;
          await _dispatch(command);
        }
      } while (_repoll);
    } catch (e) {
      debugPrint('WatchControl.poll error: $e');
    } finally {
      _handling = false;
    }
  }

  Future<void> _dispatch(String command) async {
    unawaited(_pushOptimistic(command));
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
    // Reflète l'état réel sur la Watch une fois l'action terminée.
    await pushState();
  }

  /// Lance une session pour le livre en cours, à sa dernière page connue.
  Future<void> _handleStart() async {
    final existing = await _activeSession();
    if (existing != null) return; // déjà une session en cours

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
      _activeKnown = false; // relu au prochain push
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
      _cachedActive = null;
      _activeKnown = true;
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

  Future<ReadingSession?> _firstActiveSession() => _activeSession();
}

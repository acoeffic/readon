// lib/services/reading_session_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/reading_session.dart';
import '../widgets/cached_book_cover.dart';
import 'analytics_service.dart';
import 'books_service.dart';
import 'challenge_service.dart';
import 'last_page_cache.dart';
import 'live_activity_service.dart';
import 'ocr_service.dart';
import 'offline_session_queue.dart';
import 'session_pause_service.dart';

/// Effective reading time helper: total elapsed since [startTime] minus the
/// cumulative pause duration persisted by [SessionPauseService].
Future<int> _effectiveSecondsFor(DateTime startTime) async {
  final pause = await SessionPauseService().getTotalPauseDuration();
  final secs = DateTime.now().difference(startTime).inSeconds - pause.inSeconds;
  return secs < 0 ? 0 : secs;
}

/// Timeout appliqué aux écritures Supabase de démarrage/fin de session.
/// En mode avion, certains appels ne échouent pas immédiatement : sans
/// timeout, l'utilisateur resterait bloqué sur le spinner au lieu de
/// basculer sur la sauvegarde locale.
const _kSessionWriteTimeout = Duration(seconds: 10);

/// Détecte les erreurs de connectivité (pas d'internet, DNS, timeout...)
/// par opposition aux vraies erreurs serveur (RLS, contrainte, 4xx/5xx).
/// On ne met en file offline QUE les échecs réseau : une erreur serveur
/// rejouée à l'infini ne réussira jamais.
bool _isNetworkError(Object e) {
  if (e is TimeoutException) return true;
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset') ||
      s.contains('Connection closed') ||
      s.contains('Connection failed') ||
      s.contains('Connection terminated') ||
      s.contains('Network is unreachable') ||
      s.contains('Software caused connection abort') ||
      s.contains('HandshakeException') ||
      s.contains('AuthRetryableFetchException');
}

class ReadingSessionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OCRService ocrService = OCRService();
  final ChallengeService _challengeService = ChallengeService();
  final OfflineSessionQueue _offlineQueue = OfflineSessionQueue();
  final BooksService _booksService = BooksService();
  final LiveActivityService _liveActivity = LiveActivityService();

  /// Compteur bumpé chaque fois qu'une session active change (créée,
  /// terminée, annulée). Permet à la coquille de navigation principale de
  /// rafraîchir la bannière « En train de lire » sans dépendre du flux de
  /// pop des routes (utile quand la fin de lecture fait
  /// `pushAndRemoveUntil` puis revient à l'accueil).
  static final ValueNotifier<int> activeSessionsVersion =
      ValueNotifier<int>(0);

  static void _notifyActiveSessionsChanged() {
    activeSessionsVersion.value++;
  }

  /// Compteur bumpé à chaque pause/reprise de session, quelle que soit son
  /// origine (bouton iPhone, Apple Watch, Live Activity). Permet à la page de
  /// session en cours et au pont Watch de refléter l'état en direct.
  static final ValueNotifier<int> pauseStateVersion = ValueNotifier<int>(0);

  static void _notifyPauseStateChanged() {
    pauseStateVersion.value++;
  }
  
  /// Démarrer une nouvelle session de lecture
  /// Soit [imagePath] est fourni (OCR extraira le numéro de page),
  /// soit [manualPageNumber] est fourni directement.
  /// Si [offlineMode] est true, la session est sauvegardée localement.
  /// Event PostHog non bloquant émis à chaque démarrage de session, quel que
  /// soit le chemin (en ligne, offline, bascule offline sur erreur réseau).
  ///
  /// `page_source` est la donnée clé : elle dit si les lecteurs photographient
  /// la page (OCR) ou saisissent le numéro à la main. C'est ce qui permettra
  /// de trancher sur la friction du scan au démarrage.
  void _trackSessionStarted({
    required bool offline,
    required String? imagePath,
    String? pageSource,
  }) {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.sessionStarted,
      properties: {
        'offline': offline,
        // `inferred` = l'utilisateur n'a rien saisi, la page vient de ce qu'on
        // savait déjà. C'est la mesure qui dira si demander une page au
        // démarrage servait à quelque chose.
        'page_source':
            pageSource ?? (imagePath != null ? 'photo' : 'manual'),
      },
    ));
  }

  Future<ReadingSession> startSession({
    required String bookId,
    String? imagePath,
    int? manualPageNumber,
    bool offlineMode = false,
    String? readingFor,
    String? pageSource,
  }) async {
    try {
      int? pageNumber = manualPageNumber;

      // Si un chemin d'image est fourni et pas de numéro manuel, extraire via OCR
      if (pageNumber == null && imagePath != null) {
        pageNumber = await ocrService.extractPageNumber(imagePath);
        if (pageNumber == null) {
          throw Exception('Impossible de détecter le numéro de page. Réessayez avec une photo plus nette.');
        }
      }

      if (pageNumber == null) {
        throw Exception('Veuillez fournir un numéro de page.');
      }

      // Mode offline : sauvegarder localement
      if (offlineMode) {
        // Vérifier les sessions offline existantes
        final offlineSession = await _offlineQueue.getOfflineActiveSession(bookId);
        if (offlineSession != null) {
          throw Exception('Une session de lecture est déjà en cours pour ce livre.');
        }

        final result = await _offlineQueue.queueStartSession(
          bookId: bookId,
          startPage: pageNumber,
          startImagePath: imagePath,
          readingFor: readingFor,
        );
        _notifyActiveSessionsChanged();
        _trackSessionStarted(
            offline: true, imagePath: imagePath, pageSource: pageSource);
        return result;
      }

      // Vérifier qu'il n'y a pas déjà une session active (tous livres confondus)
      final activeSessions = await getAllActiveSessions();
      if (activeSessions.isNotEmpty) {
        throw Exception('Une session de lecture est déjà en cours.');
      }

      // Créer la session dans Supabase
      final now = DateTime.now();

      final insertData = <String, dynamic>{
        'book_id': bookId,
        'start_page': pageNumber,
        'start_time': now.toUtc().toIso8601String(),
        'user_id': _supabase.auth.currentUser!.id,
      };
      if (imagePath != null) {
        insertData['start_image_path'] = imagePath;
      }
      if (readingFor != null) {
        insertData['reading_for'] = readingFor;
      }

      // Filet de sécurité : si l'écriture échoue pour cause réseau (détection
      // de connectivité en retard ou erronée — mode avion, tunnel, wifi sans
      // internet...), on bascule sur la file offline au lieu de perdre la
      // session avec une erreur.
      final Map<String, dynamic> response;
      try {
        response = await _supabase
            .from('reading_sessions')
            .insert(insertData)
            .select()
            .single()
            .timeout(_kSessionWriteTimeout);
      } catch (e) {
        if (_isNetworkError(e)) {
          debugPrint('startSession: réseau indisponible, bascule offline ($e)');
          final result = await _offlineQueue.queueStartSession(
            bookId: bookId,
            startPage: pageNumber,
            startImagePath: imagePath,
            readingFor: readingFor,
          );
          _notifyActiveSessionsChanged();
          _trackSessionStarted(
            offline: true, imagePath: imagePath, pageSource: pageSource);
          return result;
        }
        rethrow;
      }

      final session = ReadingSession.fromJson(response);
      _trackSessionStarted(
          offline: false, imagePath: imagePath, pageSource: pageSource);

      // Reprendre un livre abandonné le repasse en lecture (non bloquant)
      try {
        final bookIdInt = int.tryParse(bookId);
        if (bookIdInt != null) {
          final userBook = await _supabase
              .from('user_books')
              .select('status')
              .eq('user_id', _supabase.auth.currentUser!.id)
              .eq('book_id', bookIdInt)
              .maybeSingle();
          if (userBook?['status'] == 'abandoned') {
            await _supabase
                .from('user_books')
                .update({'status': 'reading'})
                .eq('user_id', _supabase.auth.currentUser!.id)
                .eq('book_id', bookIdInt);
          }
        }
      } catch (e) {
        debugPrint('Erreur reprise livre abandonné (non bloquante): $e');
      }

      // Démarre la Live Activity iOS (no-op ailleurs).
      _startLiveActivityFor(session).catchError((e) {
        debugPrint('Live Activity start a échoué (non bloquant): $e');
      });

      _notifyActiveSessionsChanged();
      return session;
    } catch (e) {
      debugPrint('Erreur startSession: $e');
      rethrow;
    }
  }

  /// Démarre la Live Activity iOS pour une session.
  /// Résout titre/auteur/couverture via BooksService puis branche le polling
  /// des commandes pause/reprendre émises par la Live Activity.
  Future<void> _startLiveActivityFor(ReadingSession session) async {
    final available = await _liveActivity.isAvailable();
    if (!available) return;

    // Infos livre (best-effort, on ne bloque pas le démarrage si ça échoue).
    String title = '';
    String author = '';
    List<String> coverUrls = const [];
    Map<String, String?>? bookInfo;
    try {
      final bookIdInt = int.tryParse(session.bookId);
      if (bookIdInt != null) {
        final Book book = await _booksService.getBookById(bookIdInt);
        title = book.title;
        author = book.author ?? '';
        // Identité du livre — permet à LiveActivityService de re-résoudre
        // la couverture en cours de session si la résolution échoue ici.
        bookInfo = {
          'imageUrl': book.coverUrl,
          'isbn': book.isbn,
          'googleId': book.googleId,
          'title': book.title,
          'author': book.author,
        };
        // Résout la même chaîne validée que CachedBookCover (Google Books /
        // Amazon / iTunes / OpenLibrary / BnF...). Le résultat passe par le
        // cache statique partagé : si la couverture est déjà affichée dans
        // l'app, c'est instantané. L'URL brute de la DB ne suffit pas : pour
        // certains livres, Google Books renvoie son placeholder gris, qui
        // s'affichait tel quel sur la Live Activity.
        try {
          coverUrls = await CachedBookCover.resolveCoverUrls(
            imageUrl: book.coverUrl,
            isbn: book.isbn,
            googleId: book.googleId,
            title: title,
            author: author,
          ).timeout(const Duration(seconds: 8));
        } catch (_) {}
        // Dernier recours : URL brute de la DB (LiveActivityService filtre
        // de toute façon les images placeholder).
        if (coverUrls.isEmpty &&
            book.coverUrl != null &&
            book.coverUrl!.isNotEmpty) {
          coverUrls = [book.coverUrl!];
        }
      }
    } catch (_) {}

    // Réinitialise les compteurs de pause pour cette session.
    await SessionPauseService().clearAll();

    await _liveActivity.start(
      sessionId: session.id,
      bookTitle: title.isEmpty ? 'Lecture en cours' : title,
      bookAuthor: author,
      coverUrls: coverUrls,
      bookInfo: bookInfo,
      accumulatedSeconds: 0,
      isPaused: false,
    );

    // Branche le polling des commandes émises par les boutons de la Live Activity.
    _liveActivity.startCommandPolling(
      onCommand: (command, sessionId) async {
        if (sessionId != session.id) return;
        if (command == 'pause') {
          await pauseSession(sessionId, startTime: session.startTime);
        } else if (command == 'resume') {
          await resumeSession(sessionId, startTime: session.startTime);
        }
      },
    );
  }

  /// Met en pause une session : gèle le timer de la Live Activity et
  /// commence à accumuler la durée de pause côté client.
  Future<void> pauseSession(String sessionId, {required DateTime startTime}) async {
    final pauseService = SessionPauseService();
    final already = await pauseService.getPausedAt();
    if (already != null) return; // déjà en pause
    await pauseService.savePauseStart(DateTime.now());

    final effective = await _effectiveSecondsFor(startTime);
    await _liveActivity.update(
      sessionId: sessionId,
      accumulatedSeconds: effective,
      isPaused: true,
    );
    _notifyPauseStateChanged();
  }

  /// Reprend une session en pause : ajoute la durée écoulée au cumul de pause
  /// et redémarre le timer de la Live Activity.
  Future<void> resumeSession(String sessionId, {required DateTime startTime}) async {
    await SessionPauseService().finalizeCurrentPause();

    final effective = await _effectiveSecondsFor(startTime);
    await _liveActivity.update(
      sessionId: sessionId,
      accumulatedSeconds: effective,
      isPaused: false,
    );
    _notifyPauseStateChanged();
  }
  
  /// Terminer une session de lecture active
  /// Soit [imagePath] est fourni (OCR extraira le numéro de page),
  /// soit [manualPageNumber] est fourni directement.
  /// Si [offlineMode] est true, la fin de session est sauvegardée localement.
  /// [activeSession] est requis en mode offline pour construire la session complète.
  Future<ReadingSession> endSession({
    required String sessionId,
    String? imagePath,
    int? manualPageNumber,
    bool offlineMode = false,
    ReadingSession? activeSession,
  }) async {
    try {
      int? pageNumber = manualPageNumber;

      // Si un chemin d'image est fourni et pas de numéro manuel, extraire via OCR
      if (pageNumber == null && imagePath != null) {
        pageNumber = await ocrService.extractPageNumber(imagePath);
        if (pageNumber == null) {
          throw Exception('Impossible de détecter le numéro de page. Réessayez avec une photo plus nette.');
        }
      }

      if (pageNumber == null) {
        throw Exception('Veuillez fournir un numéro de page.');
      }

      final int endPageNumber = pageNumber;

      // Mémorisation locale immédiate : c'est le moment où la page atteinte
      // est la plus fiable, et le seul dont on dispose hors ligne.
      final cachedBookId = activeSession?.bookId;
      if (cachedBookId != null) {
        unawaited(LastPageCache.set(cachedBookId, endPageNumber));
      }

      // Fin de session locale, commune à tous les chemins offline :
      // end_time ajusté du cumul des pauses (comme le chemin online), état
      // de pause nettoyé, Live Activity terminée (API locale iOS, fonctionne
      // sans réseau — sinon elle restait affichée après une fin en mode avion).
      Future<ReadingSession> queueOfflineEnd(ReadingSession active) async {
        final pauseService = SessionPauseService();
        final totalPause = await pauseService.getTotalPauseDuration();
        final adjustedEnd = DateTime.now().subtract(totalPause);
        await pauseService.clearAll();
        try {
          await _liveActivity.end(sessionId: active.id);
        } catch (e) {
          debugPrint('Live Activity end offline (non bloquant): $e');
        }
        final result = await _offlineQueue.queueEndSession(
          activeSession: active,
          endPage: endPageNumber,
          endImagePath: imagePath,
          endTime: adjustedEnd,
        );
        _notifyActiveSessionsChanged();
        return result;
      }

      // Mode offline : sauvegarder localement
      if (offlineMode && activeSession != null) {
        return queueOfflineEnd(activeSession);
      }

      // Session démarrée hors ligne (id temp `offline_…`) et on est maintenant
      // en ligne : aucune ligne Supabase n'existe encore, donc l'UPDATE de fin
      // ne trouverait rien (« Session introuvable »). On pousse d'abord le
      // démarrage en attente pour obtenir un vrai id, puis on termine
      // normalement. Si l'insert échoue (hors ligne réel), on met la fin en
      // file d'attente comme en mode offline.
      var effectiveSessionId = sessionId;
      if (sessionId.startsWith('offline_')) {
        final realId = await _offlineQueue.flushStartAndGetRealId(sessionId);
        if (realId != null) {
          effectiveSessionId = realId;
        } else if (activeSession != null) {
          return queueOfflineEnd(activeSession);
        } else {
          throw Exception('Session hors ligne introuvable.');
        }
      }

      // `end_time` = maintenant - cumul des pauses, pour que la durée
      // calculée (endTime - startTime) reflète uniquement la lecture effective.
      // Inclut la pause en cours, le cas échéant.
      final pauseService = SessionPauseService();
      final totalPause = await pauseService.getTotalPauseDuration();
      final adjustedEnd = DateTime.now().subtract(totalPause);
      await pauseService.clearAll();

      // Termine la Live Activity (no-op si pas iOS ou pas démarrée).
      await _liveActivity.end(sessionId: sessionId);

      // Mettre à jour la session
      final updateData = <String, dynamic>{
        'end_page': endPageNumber,
        'end_time': adjustedEnd.toUtc().toIso8601String(),
      };
      if (imagePath != null) {
        updateData['end_image_path'] = imagePath;
      }

      // Filet de sécurité : si l'UPDATE échoue pour cause réseau (détection
      // de connectivité en retard ou erronée), on met la fin en file offline
      // au lieu de perdre la session avec une erreur. `end_time` réutilise
      // `adjustedEnd` (les pauses viennent d'être finalisées via clearAll).
      final Map<String, dynamic>? response;
      try {
        response = await _supabase
            .from('reading_sessions')
            .update(updateData)
            .eq('id', effectiveSessionId)
            .eq('user_id', _supabase.auth.currentUser!.id)
            .select()
            .maybeSingle()
            .timeout(_kSessionWriteTimeout);
      } catch (e) {
        if (_isNetworkError(e) && activeSession != null) {
          debugPrint('endSession: réseau indisponible, bascule offline ($e)');
          // `effectiveSessionId` : si le démarrage offline vient d'être poussé
          // (flushStartAndGetRealId), la fin doit référencer le vrai id.
          final result = await _offlineQueue.queueEndSession(
            activeSession: activeSession.copyWith(id: effectiveSessionId),
            endPage: endPageNumber,
            endImagePath: imagePath,
            endTime: adjustedEnd,
          );
          _notifyActiveSessionsChanged();
          return result;
        }
        rethrow;
      }

      if (response == null) {
        throw Exception('Session introuvable ou déjà terminée.');
      }

      final session = ReadingSession.fromJson(response);

      unawaited(AnalyticsService().track(
        AnalyticsEvent.sessionEnded,
        properties: {
          'pages_read': session.pagesRead,
          'duration_minutes': session.durationMinutes,
        },
      ));

      // Mettre à jour la progression des défis
      try {
        await _challengeService.updateProgressAfterSession(
          bookId: session.bookId,
          pagesRead: session.pagesRead,
          durationMinutes: session.durationMinutes,
        );
      } catch (_) {
        // Ne pas bloquer la fin de session si la mise à jour des défis échoue
      }

      _notifyActiveSessionsChanged();
      return session;
    } catch (e) {
      debugPrint('Erreur endSession: $e');
      rethrow;
    }
  }
  
  /// Récupérer la session active pour un livre (inclut les sessions offline)
  Future<ReadingSession?> getActiveSession(String bookId) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select()
          .eq('book_id', bookId)
          .eq('user_id', _supabase.auth.currentUser!.id)
          .isFilter('end_page', null)
          .maybeSingle();

      if (response != null) return ReadingSession.fromJson(response);

      // Vérifier aussi les sessions offline
      return await _offlineQueue.getOfflineActiveSession(bookId);
    } catch (e) {
      debugPrint('Erreur getActiveSession: $e');
      // En cas d'erreur réseau, vérifier les sessions offline
      try {
        return await _offlineQueue.getOfflineActiveSession(bookId);
      } catch (_) {
        return null;
      }
    }
  }

  /// Récupérer toutes les sessions actives (tous livres confondus, inclut offline)
  Future<List<ReadingSession>> getAllActiveSessions() async {
    final List<ReadingSession> sessions = [];

    try {
      final response = await _supabase
          .from('reading_sessions')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .isFilter('end_page', null)
          .order('start_time', ascending: false);

      sessions.addAll(
        (response as List).map((json) => ReadingSession.fromJson(json)),
      );
    } catch (e) {
      debugPrint('Erreur getAllActiveSessions (Supabase): $e');
    }

    // Ajouter les sessions offline
    try {
      final offlineSessions = await _offlineQueue.getAllOfflineActiveSessions();
      sessions.addAll(offlineSessions);
    } catch (e) {
      debugPrint('Erreur getAllActiveSessions (offline): $e');
    }

    return sessions;
  }
  
  /// Récupérer toutes les sessions d'un livre (historique)
  Future<List<ReadingSession>> getBookSessions(String bookId) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select()
          .eq('book_id', bookId)
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('start_time', ascending: false);
      
      return (response as List)
          .map((json) => ReadingSession.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getBookSessions: $e');
      return [];
    }
  }
  
  /// Calculer les statistiques de lecture d'un livre
  Future<BookReadingStats> getBookStats(String bookId) async {
    try {
      final results = await Future.wait<dynamic>([
        getBookSessions(bookId),
        // Progression Kindle (sync JSON) : un livre lu sur Kindle a une page
        // courante même sans aucune session LexDay.
        BooksService().getKindleCurrentPage(bookId),
      ]);
      final sessions = results[0] as List<ReadingSession>;
      final kindlePage = results[1] as int?;
      
      // Filtrer uniquement les sessions complètes
      final completedSessions = sessions.where((s) => s.endPage != null).toList();
      
      if (completedSessions.isEmpty) {
        if (kindlePage != null) {
          unawaited(LastPageCache.set(bookId, kindlePage));
        }
        return BookReadingStats(
          totalPagesRead: 0,
          totalMinutesRead: 0,
          currentPage: kindlePage,
          sessionsCount: 0,
          avgPagesPerSession: 0,
          avgMinutesPerPage: 0,
        );
      }
      
      int totalPages = completedSessions.fold(0, (sum, s) => sum + s.pagesRead);
      int totalMinutes = completedSessions.fold(0, (sum, s) => sum + s.durationMinutes);
      // Page courante = page la plus avancée atteinte sur le livre, et non
      // le end_page de la session la plus récente par horodatage. Une lecture
      // passée saisie a posteriori (is_manual) porte un horaire approximatif
      // (21:00 par défaut pour un jour passé) qui peut la classer AVANT la
      // vraie dernière session du même jour : la progression semblait alors
      // "non comptabilisée". Corollaire spec (test 8) : une session antidatée
      // plus ancienne ne doit jamais faire reculer la page courante.
      int? currentPage = completedSessions
          .map((s) => s.endPage!)
          .reduce((a, b) => a > b ? a : b);
      // Kindle peut être plus avancé que la dernière session LexDay.
      if (kindlePage != null && kindlePage > (currentPage ?? 0)) currentPage = kindlePage;

      // On tient la vérité : on la mémorise en local pour que le prochain
      // démarrage hors ligne ne reparte pas à la page 1. Voir [LastPageCache].
      if (currentPage != null) {
        unawaited(LastPageCache.set(bookId, currentPage));
      }
      
      double avgPagesPerSession = totalPages / completedSessions.length;
      double avgMinutesPerPage = totalPages > 0 ? totalMinutes / totalPages : 0;
      
      return BookReadingStats(
        totalPagesRead: totalPages,
        totalMinutesRead: totalMinutes,
        currentPage: currentPage,
        sessionsCount: completedSessions.length,
        avgPagesPerSession: avgPagesPerSession,
        avgMinutesPerPage: avgMinutesPerPage,
      );
    } catch (e) {
      debugPrint('Erreur getBookStats: $e');
      return BookReadingStats(
        totalPagesRead: 0,
        totalMinutesRead: 0,
        currentPage: null,
        sessionsCount: 0,
        avgPagesPerSession: 0,
        avgMinutesPerPage: 0,
      );
    }
  }
  
  /// Récupérer les sessions de l'utilisateur avec pagination
  /// [limit] : nombre de sessions par page (défaut 20)
  /// [offset] : décalage pour la pagination (défaut 0)
  /// Retourne les sessions avec leurs infos de livre
  Future<List<Map<String, dynamic>>> getSessionsPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // 1. Récupérer les sessions paginées
      final sessions = await _supabase
          .from('reading_sessions')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('start_time', ascending: false)
          .range(offset, offset + limit - 1);

      final sessionsList = List<Map<String, dynamic>>.from(sessions as List);
      if (sessionsList.isEmpty) return [];

      // 2. Récupérer les book_ids uniques
      final bookIds = sessionsList
          .map((s) => s['book_id'] as String)
          .toSet()
          .map((id) => int.tryParse(id))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      // 3. Récupérer les livres correspondants
      Map<int, Map<String, dynamic>> booksMap = {};
      if (bookIds.isNotEmpty) {
        final booksResponse = await _supabase
            .from('books')
            .select()
            .inFilter('id', bookIds);

        for (final book in (booksResponse as List)) {
          final bookData = Map<String, dynamic>.from(book);
          booksMap[bookData['id'] as int] = bookData;
        }
      }

      // 4. Combiner sessions + livres
      for (final session in sessionsList) {
        final bookId = int.tryParse(session['book_id'] as String);
        session['books'] = bookId != null ? booksMap[bookId] : null;
      }

      return sessionsList;
    } catch (e) {
      debugPrint('Erreur getSessionsPaginated: $e');
      return [];
    }
  }

  /// Récupérer toutes les sessions de l'utilisateur avec les infos des livres
  /// DEPRECATED: Utiliser getSessionsPaginated pour de meilleures performances
  Future<List<Map<String, dynamic>>> getAllUserSessionsWithBook() async {
    return getSessionsPaginated(limit: 200, offset: 0);
  }

  /// Masquer ou afficher une session vis-à-vis des autres utilisateurs
  Future<void> toggleSessionHidden(String sessionId, bool isHidden) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');
      await _supabase
          .from('reading_sessions')
          .update({'is_hidden': isHidden})
          .eq('id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Erreur toggleSessionHidden: $e');
      rethrow;
    }
  }

  /// Modifier a posteriori « pour qui » une session a été lue.
  ///
  /// [readingFor] : clé ('son', 'mother', …) ou `null` pour revenir à une
  /// lecture pour soi (convention identique au démarrage de session :
  /// 'myself' n'est jamais stocké, on met NULL).
  Future<void> updateSessionReadingFor(
    String sessionId,
    String? readingFor,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');
      await _supabase
          .from('reading_sessions')
          .update({'reading_for': readingFor})
          .eq('id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Erreur updateSessionReadingFor: $e');
      rethrow;
    }
  }

  /// Rythme personnel en minutes par page, calculé sur les dernières sessions
  /// réellement trackées (ni Kindle, ni saisies manuelles : celles-là portent
  /// déjà une durée déclarée ou estimée). `null` si pas assez d'historique.
  Future<double?> getPersonalMinutesPerPage({int sampleSize = 50}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final rows = await _supabase
          .from('reading_sessions')
          .select('start_page, end_page, start_time, end_time')
          .eq('user_id', userId)
          .eq('is_manual', false)
          .not('end_time', 'is', null)
          .not('end_page', 'is', null)
          .order('end_time', ascending: false)
          .limit(sampleSize);
      var pages = 0;
      var minutes = 0.0;
      for (final r in rows as List) {
        final sp = (r['start_page'] as num?)?.toInt();
        final ep = (r['end_page'] as num?)?.toInt();
        if (sp == null || ep == null || ep <= sp) continue;
        final st = DateTime.tryParse(r['start_time'] as String? ?? '');
        final et = DateTime.tryParse(r['end_time'] as String? ?? '');
        if (st == null || et == null) continue;
        final m = et.difference(st).inSeconds / 60.0;
        if (m <= 0) continue;
        pages += ep - sp;
        minutes += m;
      }
      if (pages < 20) return null;
      return minutes / pages;
    } catch (e) {
      debugPrint('Erreur getPersonalMinutesPerPage: $e');
      return null;
    }
  }

  /// Durée estimée pour [pages] pages au rythme personnel (repli
  /// [defaultMinutesPerPage]), bornée : rythme entre 0,5 et 5 min/page,
  /// total entre 1 min et [maxDuration]. Sert aux sessions Kindle, dont on
  /// ne connaît que le delta de pages.
  Future<Duration> estimateDurationForPages(
    int pages, {
    double defaultMinutesPerPage = 1.5,
    Duration maxDuration = const Duration(hours: 3),
  }) async {
    final personal = await getPersonalMinutesPerPage();
    final perPage = (personal ?? defaultMinutesPerPage).clamp(0.5, 5.0);
    final minutes = (pages * perPage).round().clamp(1, maxDuration.inMinutes);
    return Duration(minutes: minutes);
  }

  /// Enregistrer une lecture passée, saisie manuellement a posteriori
  /// ("Ajouter une lecture passée" : chrono oublié).
  ///
  /// Insert-then-update obligatoire : le trigger feed d'activités est
  /// AFTER UPDATE only, avec garde sur la transition end_time NULL → NOT NULL.
  /// Un INSERT avec end_time déjà rempli ne créerait pas l'activité feed.
  ///
  /// [endTime] est borné à [maintenant - 1 an, maintenant]. Une session
  /// antidatée (endTime un autre jour qu'aujourd'hui) compte pour les
  /// stats/feed/défis mais pas pour la flamme (voir FlowService).
  /// Ne démarre pas de Live Activity (sessions temps réel uniquement).
  Future<ReadingSession> insertPastSession({
    required String bookId,
    required int startPage,
    required int endPage,
    required Duration duration,
    DateTime? endTime,
    String? source,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');
      if (endPage < startPage) {
        throw ArgumentError('endPage doit être >= startPage');
      }
      if (duration <= Duration.zero) {
        throw ArgumentError('duration doit être positive');
      }

      // Borner la date de fin : pas de futur, pas plus d'un an en arrière.
      final now = DateTime.now();
      var effectiveEnd = endTime ?? now;
      if (effectiveEnd.isAfter(now)) effectiveEnd = now;
      final oneYearAgo = now.subtract(const Duration(days: 365));
      if (effectiveEnd.isBefore(oneYearAgo)) effectiveEnd = oneYearAgo;

      // start_time = end_time - durée, tronqué à minuit du même jour pour que
      // la session ne chevauche pas la veille (la flamme ne regarde que
      // end_time, mais les stats horaires restent cohérentes).
      var effectiveStart = effectiveEnd.subtract(duration);
      final midnight =
          DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);
      if (effectiveStart.isBefore(midnight)) effectiveStart = midnight;

      // 1) Ligne ouverte (le trigger feed ne se déclenche pas sur INSERT).
      final inserted = await _supabase
          .from('reading_sessions')
          .insert({
            'book_id': bookId,
            'user_id': userId,
            'start_page': startPage,
            'start_time': effectiveStart.toUtc().toIso8601String(),
            'is_manual': true,
            if (source != null) 'source': source,
          })
          .select()
          .single();
      final sessionId = inserted['id'] as String;

      // 2) Fermeture immédiate : transition end_time NULL → NOT NULL, qui
      // déclenche le trigger feed (dédup par session_id côté SQL).
      final response = await _supabase
          .from('reading_sessions')
          .update({
            'end_page': endPage,
            'end_time': effectiveEnd.toUtc().toIso8601String(),
          })
          .eq('id', sessionId)
          .eq('user_id', userId)
          .select()
          .single();

      final session = ReadingSession.fromJson(response);

      // Répercuter sur les défis (comme endSession), sans bloquer.
      try {
        await _challengeService.updateProgressAfterSession(
          bookId: session.bookId,
          pagesRead: session.pagesRead,
          durationMinutes: session.durationMinutes,
        );
      } catch (_) {}

      _notifyActiveSessionsChanged();
      return session;
    } catch (e) {
      debugPrint('Erreur insertPastSession: $e');
      rethrow;
    }
  }

  /// Corriger les pages d'une session déjà terminée.
  ///
  /// Utilisé par le rattrapage des sessions pilotées depuis l'Apple Watch,
  /// terminées sans page de fin fiable. Répercute le delta de pages sur la
  /// progression des défis (la durée a déjà été comptée à la fin de session).
  /// La page courante du livre étant dérivée du `end_page` de la dernière
  /// session, la progression du livre est corrigée automatiquement.
  Future<ReadingSession> updateSessionPages({
    required String sessionId,
    int? startPage,
    int? endPage,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      final updateData = <String, dynamic>{};
      if (startPage != null) updateData['start_page'] = startPage;
      if (endPage != null) updateData['end_page'] = endPage;
      if (updateData.isEmpty) {
        throw ArgumentError('startPage ou endPage requis');
      }

      // Pages lues avant correction, pour le delta des défis.
      final before = await _supabase
          .from('reading_sessions')
          .select()
          .eq('id', sessionId)
          .eq('user_id', userId)
          .maybeSingle();
      if (before == null) throw Exception('Session introuvable.');
      final oldSession = ReadingSession.fromJson(before);

      final response = await _supabase
          .from('reading_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .eq('user_id', userId)
          .select()
          .maybeSingle();
      if (response == null) throw Exception('Session introuvable.');
      final session = ReadingSession.fromJson(response);

      final deltaPages = session.pagesRead - oldSession.pagesRead;
      if (deltaPages != 0) {
        try {
          await _challengeService.updateProgressAfterSession(
            bookId: session.bookId,
            pagesRead: deltaPages,
            durationMinutes: 0,
          );
        } catch (_) {
          // Ne pas bloquer la correction si la mise à jour des défis échoue.
        }
      }

      _notifyActiveSessionsChanged();
      return session;
    } catch (e) {
      debugPrint('Erreur updateSessionPages: $e');
      rethrow;
    }
  }

  /// Récupérer les moyennes de lecture globales de l'utilisateur
  /// Retourne avgMinutesPerPage, avgPagesPerDay, totalPages, totalMinutes
  Future<Map<String, double>> getUserReadingAverages() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return _emptyAverages;

      final response = await _supabase
          .from('reading_sessions')
          .select('start_time, end_time, start_page, end_page')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .order('start_time', ascending: true);

      final sessions = List<Map<String, dynamic>>.from(response as List);
      if (sessions.isEmpty) return _emptyAverages;

      int totalPages = 0;
      int totalMinutes = 0;
      final readingDays = <String>{};

      for (final s in sessions) {
        final st = DateTime.parse(s['start_time'] as String);
        final et = DateTime.parse(s['end_time'] as String);
        final mins = et.difference(st).inMinutes;
        if (mins <= 0) continue;

        final startPage = (s['start_page'] as num?)?.toInt() ?? 0;
        final endPage = (s['end_page'] as num?)?.toInt() ?? 0;
        final pages = endPage > startPage ? endPage - startPage : 0;

        totalPages += pages;
        totalMinutes += mins;
        readingDays.add('${st.year}-${st.month}-${st.day}');
      }

      if (totalPages == 0 || totalMinutes == 0) return _emptyAverages;

      final avgMinutesPerPage = totalMinutes / totalPages;

      // Pages par jour basé sur les jours où l'utilisateur a lu
      final firstSession = DateTime.parse(sessions.first['start_time'] as String);
      final daysSinceFirst = DateTime.now().difference(firstSession).inDays;
      final totalDays = daysSinceFirst > 0 ? daysSinceFirst : 1;
      final avgPagesPerDay = totalPages / totalDays;

      return {
        'avg_minutes_per_page': avgMinutesPerPage,
        'avg_pages_per_day': avgPagesPerDay,
        'total_pages': totalPages.toDouble(),
        'total_minutes': totalMinutes.toDouble(),
      };
    } catch (e) {
      debugPrint('Erreur getUserReadingAverages: $e');
      return _emptyAverages;
    }
  }

  static const _emptyAverages = {
    'avg_minutes_per_page': 0.0,
    'avg_pages_per_day': 0.0,
    'total_pages': 0.0,
    'total_minutes': 0.0,
  };

  /// Annuler une session active
  Future<void> cancelSession(String sessionId) async {
    try {
      // Combien de temps de lecture part à la poubelle : c'est la mesure qui
      // dira si l'abandon reste un cas rare et volontaire, ou s'il sert de
      // porte de sortie à un écran de fin trop exigeant.
      unawaited(AnalyticsService().track(
        AnalyticsEvent.sessionAbandoned,
        properties: {'session_id': sessionId},
      ));

      // Nettoie l'état de pause et ferme la Live Activity avant suppression DB.
      await SessionPauseService().clearAll();
      await _liveActivity.end(sessionId: sessionId);

      // Session démarrée hors ligne : elle n'existe que dans la file locale
      // (un DELETE Supabase sur un id `offline_…` échouerait de toute façon,
      // la colonne est un uuid).
      if (sessionId.startsWith('offline_')) {
        await _offlineQueue.removeOfflineStartSession(sessionId);
        _notifyActiveSessionsChanged();
        return;
      }

      await _supabase
          .from('reading_sessions')
          .delete()
          .eq('id', sessionId);

      _notifyActiveSessionsChanged();
    } catch (e) {
      debugPrint('Erreur cancelSession: $e');
      rethrow;
    }
  }
  
  void dispose() {
    ocrService.dispose();
  }
}
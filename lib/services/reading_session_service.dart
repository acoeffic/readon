// lib/services/reading_session_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/reading_session.dart';
import 'books_service.dart';
import 'challenge_service.dart';
import 'live_activity_service.dart';
import 'ocr_service.dart';
import 'offline_session_queue.dart';

/// État de pause d'une session (partagé entre toutes les instances du service,
/// car les pauses/reprises ne sont pas persistées en base : on ajuste `end_time`
/// au moment de `endSession` pour que la durée calculée reste correcte.
class _PauseTracker {
  /// Secondes cumulées de pause pour une session (clé = sessionId).
  static final Map<String, int> totalPausedSeconds = {};
  /// Timestamp du début de la pause courante, si la session est en pause.
  static final Map<String, DateTime> pausedAt = {};

  /// Secondes accumulées en lecture effective (utilisé par la Live Activity).
  static int effectiveSecondsForSession(DateTime startTime, String sessionId) {
    final now = DateTime.now();
    int total = now.difference(startTime).inSeconds;
    total -= totalPausedSeconds[sessionId] ?? 0;
    final currentPause = pausedAt[sessionId];
    if (currentPause != null) {
      total -= now.difference(currentPause).inSeconds;
    }
    return total < 0 ? 0 : total;
  }
}

class ReadingSessionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OCRService ocrService = OCRService();
  final ChallengeService _challengeService = ChallengeService();
  final OfflineSessionQueue _offlineQueue = OfflineSessionQueue();
  final BooksService _booksService = BooksService();
  final LiveActivityService _liveActivity = LiveActivityService();
  
  /// Démarrer une nouvelle session de lecture
  /// Soit [imagePath] est fourni (OCR extraira le numéro de page),
  /// soit [manualPageNumber] est fourni directement.
  /// Si [offlineMode] est true, la session est sauvegardée localement.
  Future<ReadingSession> startSession({
    required String bookId,
    String? imagePath,
    int? manualPageNumber,
    bool offlineMode = false,
    String? readingFor,
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

        return await _offlineQueue.queueStartSession(
          bookId: bookId,
          startPage: pageNumber,
          startImagePath: imagePath,
        );
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

      final response = await _supabase
          .from('reading_sessions')
          .insert(insertData)
          .select()
          .single();

      final session = ReadingSession.fromJson(response);

      // Démarre la Live Activity iOS (no-op ailleurs).
      _startLiveActivityFor(session).catchError((e) {
        debugPrint('Live Activity start a échoué (non bloquant): $e');
      });

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
    String? coverUrl;
    try {
      final bookIdInt = int.tryParse(session.bookId);
      if (bookIdInt != null) {
        final Book book = await _booksService.getBookById(bookIdInt);
        title = book.title;
        author = book.author ?? '';
        coverUrl = book.coverUrl;
      }
    } catch (_) {}

    // Réinitialise les compteurs de pause pour cette session.
    _PauseTracker.totalPausedSeconds.remove(session.id);
    _PauseTracker.pausedAt.remove(session.id);

    await _liveActivity.start(
      sessionId: session.id,
      bookTitle: title.isEmpty ? 'Lecture en cours' : title,
      bookAuthor: author,
      coverUrl: coverUrl,
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
    if (_PauseTracker.pausedAt.containsKey(sessionId)) return; // déjà en pause
    _PauseTracker.pausedAt[sessionId] = DateTime.now();

    final effective = _PauseTracker.effectiveSecondsForSession(startTime, sessionId);
    await _liveActivity.update(
      sessionId: sessionId,
      accumulatedSeconds: effective,
      isPaused: true,
    );
  }

  /// Reprend une session en pause : ajoute la durée écoulée au cumul de pause
  /// et redémarre le timer de la Live Activity.
  Future<void> resumeSession(String sessionId, {required DateTime startTime}) async {
    final pausedAt = _PauseTracker.pausedAt.remove(sessionId);
    if (pausedAt != null) {
      final previous = _PauseTracker.totalPausedSeconds[sessionId] ?? 0;
      _PauseTracker.totalPausedSeconds[sessionId] =
          previous + DateTime.now().difference(pausedAt).inSeconds;
    }

    final effective = _PauseTracker.effectiveSecondsForSession(startTime, sessionId);
    await _liveActivity.update(
      sessionId: sessionId,
      accumulatedSeconds: effective,
      isPaused: false,
    );
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

      // Mode offline : sauvegarder localement
      if (offlineMode && activeSession != null) {
        return await _offlineQueue.queueEndSession(
          activeSession: activeSession,
          endPage: pageNumber,
          endImagePath: imagePath,
        );
      }

      // Si une pause est en cours, la clôture d'abord pour comptabiliser sa durée.
      final currentPause = _PauseTracker.pausedAt.remove(sessionId);
      if (currentPause != null) {
        final prev = _PauseTracker.totalPausedSeconds[sessionId] ?? 0;
        _PauseTracker.totalPausedSeconds[sessionId] =
            prev + DateTime.now().difference(currentPause).inSeconds;
      }

      // `end_time` = maintenant - cumul des pauses, pour que la durée
      // calculée (endTime - startTime) reflète uniquement la lecture effective.
      final pausedSec = _PauseTracker.totalPausedSeconds.remove(sessionId) ?? 0;
      final adjustedEnd = DateTime.now().subtract(Duration(seconds: pausedSec));

      // Termine la Live Activity (no-op si pas iOS ou pas démarrée).
      await _liveActivity.end(sessionId: sessionId);

      // Mettre à jour la session
      final updateData = <String, dynamic>{
        'end_page': pageNumber,
        'end_time': adjustedEnd.toUtc().toIso8601String(),
      };
      if (imagePath != null) {
        updateData['end_image_path'] = imagePath;
      }

      final response = await _supabase
          .from('reading_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .eq('user_id', _supabase.auth.currentUser!.id)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Session introuvable ou déjà terminée.');
      }

      final session = ReadingSession.fromJson(response);

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
      final sessions = await getBookSessions(bookId);
      
      // Filtrer uniquement les sessions complètes
      final completedSessions = sessions.where((s) => s.endPage != null).toList();
      
      if (completedSessions.isEmpty) {
        return BookReadingStats(
          totalPagesRead: 0,
          totalMinutesRead: 0,
          currentPage: null,
          sessionsCount: 0,
          avgPagesPerSession: 0,
          avgMinutesPerPage: 0,
        );
      }
      
      int totalPages = completedSessions.fold(0, (sum, s) => sum + s.pagesRead);
      int totalMinutes = completedSessions.fold(0, (sum, s) => sum + s.durationMinutes);
      int? currentPage = completedSessions.first.endPage; // Dernière page lue
      
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
      // Nettoie l'état de pause et ferme la Live Activity avant suppression DB.
      _PauseTracker.totalPausedSeconds.remove(sessionId);
      _PauseTracker.pausedAt.remove(sessionId);
      await _liveActivity.end(sessionId: sessionId);

      await _supabase
          .from('reading_sessions')
          .delete()
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('Erreur cancelSession: $e');
      rethrow;
    }
  }
  
  void dispose() {
    ocrService.dispose();
  }
}
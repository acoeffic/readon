// lib/services/reading_session_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_session.dart';
import 'ocr_service.dart';
import 'challenge_service.dart';

class ReadingSessionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OCRService ocrService = OCRService();
  final ChallengeService _challengeService = ChallengeService();
  
  /// Démarrer une nouvelle session de lecture
  /// Soit [imagePath] est fourni (OCR extraira le numéro de page),
  /// soit [manualPageNumber] est fourni directement.
  Future<ReadingSession> startSession({
    required String bookId,
    String? imagePath,
    int? manualPageNumber,
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

      // Vérifier qu'il n'y a pas déjà une session active pour ce livre
      final activeSession = await getActiveSession(bookId);
      if (activeSession != null) {
        throw Exception('Une session de lecture est déjà en cours pour ce livre.');
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

      final response = await _supabase
          .from('reading_sessions')
          .insert(insertData)
          .select()
          .single();

      return ReadingSession.fromJson(response);
    } catch (e) {
      debugPrint('Erreur startSession: $e');
      rethrow;
    }
  }
  
  /// Terminer une session de lecture active
  /// Soit [imagePath] est fourni (OCR extraira le numéro de page),
  /// soit [manualPageNumber] est fourni directement.
  Future<ReadingSession> endSession({
    required String sessionId,
    String? imagePath,
    int? manualPageNumber,
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

      // Mettre à jour la session
      final updateData = <String, dynamic>{
        'end_page': pageNumber,
        'end_time': DateTime.now().toUtc().toIso8601String(),
      };
      if (imagePath != null) {
        updateData['end_image_path'] = imagePath;
      }

      final response = await _supabase
          .from('reading_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

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
  
  /// Récupérer la session active pour un livre
  Future<ReadingSession?> getActiveSession(String bookId) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select()
          .eq('book_id', bookId)
          .eq('user_id', _supabase.auth.currentUser!.id)
          .isFilter('end_page', null)
          .maybeSingle();
      
      if (response == null) return null;
      
      return ReadingSession.fromJson(response);
    } catch (e) {
      debugPrint('Erreur getActiveSession: $e');
      return null;
    }
  }
  
  /// Récupérer toutes les sessions actives (tous livres confondus)
  Future<List<ReadingSession>> getAllActiveSessions() async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .isFilter('end_page', null)
          .order('start_time', ascending: false);
      
      return (response as List)
          .map((json) => ReadingSession.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getAllActiveSessions: $e');
      return [];
    }
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

  /// Annuler une session active
  Future<void> cancelSession(String sessionId) async {
    try {
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
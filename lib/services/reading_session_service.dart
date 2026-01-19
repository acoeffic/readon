// lib/services/reading_session_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_session.dart';
import 'ocr_service.dart';

class ReadingSessionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OCRService ocrService = OCRService();
  
  /// Démarrer une nouvelle session de lecture
  Future<ReadingSession> startSession({
    required String bookId,
    required String imagePath,
  }) async {
    try {
      // 1. Extraire le numéro de page avec OCR
      final pageNumber = await ocrService.extractPageNumber(imagePath);
      
      if (pageNumber == null) {
        throw Exception('Impossible de détecter le numéro de page. Réessayez avec une photo plus nette.');
      }
      
      // 2. Vérifier qu'il n'y a pas déjà une session active pour ce livre
      final activeSession = await getActiveSession(bookId);
      if (activeSession != null) {
        throw Exception('Une session de lecture est déjà en cours pour ce livre.');
      }
      
      // 3. Créer la session dans Supabase
      final now = DateTime.now();
      print('DEBUG startSession - DateTime.now(): $now');
      print('DEBUG startSession - toUtc(): ${now.toUtc()}');
      print('DEBUG startSession - toIso8601String(): ${now.toUtc().toIso8601String()}');

      final response = await _supabase
          .from('reading_sessions')
          .insert({
            'book_id': bookId,
            'start_page': pageNumber,
            'start_time': now.toUtc().toIso8601String(),
            'user_id': _supabase.auth.currentUser!.id,
            'start_image_path': imagePath, // Optionnel: stocker le chemin local
          })
          .select()
          .single();

      print('DEBUG startSession - Response start_time: ${response['start_time']}');
      
      return ReadingSession.fromJson(response);
    } catch (e) {
      print('Erreur startSession: $e');
      rethrow;
    }
  }
  
  /// Terminer une session de lecture active
  Future<ReadingSession> endSession({
    required String sessionId,
    required String imagePath,
  }) async {
    try {
      // 1. Extraire le numéro de page de fin avec OCR
      final pageNumber = await ocrService.extractPageNumber(imagePath);
      
      if (pageNumber == null) {
        throw Exception('Impossible de détecter le numéro de page. Réessayez avec une photo plus nette.');
      }
      
      // 2. Mettre à jour la session
      final response = await _supabase
          .from('reading_sessions')
          .update({
            'end_page': pageNumber,
            'end_time': DateTime.now().toIso8601String(),
            'end_image_path': imagePath,
          })
          .eq('id', sessionId)
          .select()
          .single();
      
      return ReadingSession.fromJson(response);
    } catch (e) {
      print('Erreur endSession: $e');
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
      print('Erreur getActiveSession: $e');
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
      print('Erreur getAllActiveSessions: $e');
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
      print('Erreur getBookSessions: $e');
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
      print('Erreur getBookStats: $e');
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
  
  /// Annuler une session active
  Future<void> cancelSession(String sessionId) async {
    try {
      await _supabase
          .from('reading_sessions')
          .delete()
          .eq('id', sessionId);
    } catch (e) {
      print('Erreur cancelSession: $e');
      rethrow;
    }
  }
  
  void dispose() {
    ocrService.dispose();
  }
}
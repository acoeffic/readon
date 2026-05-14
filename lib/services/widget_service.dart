// lib/services/widget_service.dart
// Service pour mettre à jour le widget iOS WidgetKit via home_widget

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/reading_flow.dart';
import '../widgets/cached_book_cover.dart';
import 'books_service.dart';
import 'flow_service.dart';

class WidgetService {
  static const String _appGroupId = 'group.fr.lexday.app';
  static const String _iOSWidgetName = 'LexDayWidget';

  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  final BooksService _booksService = BooksService();
  final FlowService _flowService = FlowService();

  // Cache pour éviter de re-télécharger la même couverture
  String? _cachedCoverUrl;
  String? _cachedCoverBase64;

  /// Initialiser le widget (à appeler au démarrage)
  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Mettre à jour le widget avec les données réelles de l'utilisateur
  Future<void> updateWidget() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Récupérer les données en parallèle
      final results = await Future.wait([
        _booksService.getCurrentReadingBook(),
        _flowService.getUserFlow(),
        _getTodayMinutes(userId),
      ]);

      final currentBookData = results[0] as Map<String, dynamic>?;
      final flow = results[1] as ReadingFlow;
      final todayMinutes = results[2] as int;

      // Données du livre en cours
      String bookTitle = 'Aucun livre';
      String bookAuthor = '';
      String bookCoverUrl = '';
      double progressPercent = 0.0;

      if (currentBookData != null) {
        final book = currentBookData['book'] as Book;
        bookTitle = book.title;
        bookAuthor = book.author ?? '';
        bookCoverUrl = await _resolveBestCoverUrl(book);

        final currentPage = currentBookData['current_page'] as int? ?? 0;
        final totalPages = currentBookData['total_pages'] as int? ?? 0;
        if (totalPages > 0) {
          progressPercent = (currentPage / totalPages).clamp(0.0, 1.0);
        }
      }

      // Streak (flow)
      final streak = flow.currentFlow;

      // Télécharger et encoder la couverture en base64 (avec cache)
      final coverBase64 = await _fetchCoverAsBase64(bookCoverUrl);

      // Envoyer les données au widget
      await Future.wait([
        HomeWidget.saveWidgetData<String>('currentBook', bookTitle),
        HomeWidget.saveWidgetData<String>('currentAuthor', bookAuthor),
        HomeWidget.saveWidgetData<String>('coverUrl', bookCoverUrl),
        HomeWidget.saveWidgetData<String>('coverBase64', coverBase64),
        HomeWidget.saveWidgetData<int>('todayMinutes', todayMinutes),
        HomeWidget.saveWidgetData<int>('streak', streak),
        HomeWidget.saveWidgetData<double>('progressPercent', progressPercent),
      ]);

      // Rafraîchir le widget iOS
      await HomeWidget.updateWidget(name: _iOSWidgetName);

      debugPrint('✅ Widget mis à jour: $bookTitle ($todayMinutes min, flow $streak)');
    } catch (e) {
      debugPrint('❌ Erreur updateWidget: $e');
    }
  }

  /// Résout la meilleure URL de couverture disponible (Google Books > Amazon
  /// via ISBN-10 > URL stockée), dans le même esprit que la chaîne utilisée
  /// par CachedBookCover. Fait un best-effort sans bloquer trop longtemps.
  Future<String> _resolveBestCoverUrl(Book book) async {
    // 1. Cache in-memory déjà résolu par CachedBookCover (si le livre a
    //    été affiché dans l'app, la bonne URL y est).
    final cached = CachedBookCover.resolvedUrl(
      imageUrl: book.coverUrl,
      isbn: book.isbn,
      googleId: book.googleId,
    );
    if (cached != null && cached.isNotEmpty) return cached;

    // 2. URL déterministe Google Books via googleId (pas d'appel réseau).
    if (book.googleId != null && book.googleId!.isNotEmpty) {
      return 'https://books.google.com/books/content'
          '?id=${book.googleId}'
          '&printsec=frontcover&img=1&zoom=3&source=gbs_api';
    }

    // 3. Amazon via ISBN (best-effort, timeout court).
    if (book.isbn != null && book.isbn!.isNotEmpty) {
      try {
        final amazonUrl = await CachedBookCover.fetchAmazonCover(book.isbn!)
            .timeout(const Duration(seconds: 3));
        if (amazonUrl != null) return amazonUrl;
      } catch (_) {}
    }

    // 4. URL brute stockée en dernier recours.
    return book.coverUrl ?? '';
  }

  /// Télécharger la couverture et la convertir en base64 pour le widget
  /// Utilise un cache pour éviter de re-télécharger la même image
  Future<String> _fetchCoverAsBase64(String coverUrl) async {
    if (coverUrl.isEmpty) return '';

    // Cache hit : pas besoin de re-télécharger
    if (_cachedCoverUrl == coverUrl && _cachedCoverBase64 != null) {
      return _cachedCoverBase64!;
    }

    try {
      final response = await http
          .get(Uri.parse(coverUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '';

      final base64 = base64Encode(response.bodyBytes);
      _cachedCoverUrl = coverUrl;
      _cachedCoverBase64 = base64;
      return base64;
    } catch (e) {
      debugPrint('Erreur _fetchCoverAsBase64: $e');
      return '';
    }
  }

  /// Calculer les minutes de lecture du jour
  Future<int> _getTodayMinutes(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final response = await Supabase.instance.client
          .from('reading_sessions')
          .select('start_time, end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', todayStart.toUtc().toIso8601String());

      int totalMinutes = 0;
      for (final session in (response as List)) {
        final startTime = DateTime.parse(session['start_time'] as String);
        final endTime = DateTime.parse(session['end_time'] as String);
        final minutes = endTime.difference(startTime).inMinutes;
        if (minutes > 0) totalMinutes += minutes;
      }

      return totalMinutes;
    } catch (e) {
      debugPrint('Erreur _getTodayMinutes: $e');
      return 0;
    }
  }
}

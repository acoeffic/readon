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
import 'watch_control_service.dart';

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

  // User-Agent type Safari iOS : Google Books / Amazon / OpenLibrary
  // refusent souvent les requêtes sans UA "navigateur" (403 ou 0 byte).
  // Même UA que CachedBookCover et LiveActivityService.
  static const _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  };

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
      List<String> coverCandidates = const [];
      double progressPercent = 0.0;

      if (currentBookData != null) {
        final book = currentBookData['book'] as Book;
        bookTitle = book.title;
        bookAuthor = book.author ?? '';
        coverCandidates = await _resolveCoverCandidates(book);

        final currentPage = currentBookData['current_page'] as int? ?? 0;
        final totalPages = currentBookData['total_pages'] as int? ?? 0;
        if (totalPages > 0) {
          progressPercent = (currentPage / totalPages).clamp(0.0, 1.0);
        }
      }

      // Streak (flow)
      final streak = flow.currentFlow;

      // Télécharger et encoder la première vraie couverture en base64
      // (avec cache, en filtrant les images placeholder).
      final coverBase64 = await _fetchCoverAsBase64(coverCandidates);
      final bookCoverUrl = coverBase64.isNotEmpty
          ? (_cachedCoverUrl ?? '')
          : (coverCandidates.isNotEmpty ? coverCandidates.first : '');

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

      // Pousse le même état vers l'app Apple Watch (no-op hors iOS / sans Watch).
      WatchControlService().pushState();

      debugPrint('✅ Widget mis à jour: $bookTitle ($todayMinutes min, flow $streak)');
    } catch (e) {
      debugPrint('❌ Erreur updateWidget: $e');
    }
  }

  /// Résout la chaîne complète de couvertures validées pour [book] — la même
  /// que celle utilisée par CachedBookCover dans l'app et par la Live
  /// Activity (Google Books / Amazon / iTunes / OpenLibrary / BnF...).
  /// Passe par le cache statique partagé : instantané si la couverture est
  /// déjà affichée dans l'app.
  Future<List<String>> _resolveCoverCandidates(Book book) async {
    try {
      final urls = await CachedBookCover.resolveCoverUrls(
        imageUrl: book.coverUrl,
        isbn: book.isbn,
        googleId: book.googleId,
        title: book.title,
        author: book.author,
      ).timeout(const Duration(seconds: 8));
      if (urls.isNotEmpty) return urls;
    } catch (_) {}
    // Dernier recours : URL brute de la DB (_fetchCoverAsBase64 filtre de
    // toute façon les images placeholder).
    return [
      if (book.coverUrl != null && book.coverUrl!.isNotEmpty) book.coverUrl!,
    ];
  }

  /// Télécharge la première vraie couverture de la liste et la convertit en
  /// base64 pour le widget. Rejette les images placeholder (GIF 1×1 Amazon,
  /// PNG gris Google Books). Utilise un cache pour éviter de re-télécharger.
  Future<String> _fetchCoverAsBase64(List<String> coverUrls) async {
    for (final coverUrl in coverUrls) {
      if (coverUrl.isEmpty) continue;

      // Cache hit : pas besoin de re-télécharger
      if (_cachedCoverUrl == coverUrl && _cachedCoverBase64 != null) {
        return _cachedCoverBase64!;
      }

      try {
        final response = await http
            .get(Uri.parse(coverUrl), headers: _browserHeaders)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        if (!CachedBookCover.looksLikeRealCover(coverUrl, response.bodyBytes)) {
          debugPrint('WidgetService: placeholder rejeté pour $coverUrl');
          continue;
        }

        final base64 = base64Encode(response.bodyBytes);
        _cachedCoverUrl = coverUrl;
        _cachedCoverBase64 = base64;
        return base64;
      } catch (e) {
        debugPrint('Erreur _fetchCoverAsBase64 ($coverUrl): $e');
      }
    }
    return '';
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

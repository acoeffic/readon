import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/kindle_webview_service.dart';
import '../services/kindle_auto_sync_service.dart';
import '../services/books_service.dart';

/// Widget invisible qui effectue un sync Kindle en arrière-plan.
/// Utilise une WebView cachée (Offstage) pour extraire les données
/// Amazon via les cookies persistants d'une connexion précédente.
class KindleAutoSyncWidget extends StatefulWidget {
  final VoidCallback onCompleted;
  final void Function(KindleReadingData data)? onSyncSuccess;

  const KindleAutoSyncWidget({
    super.key,
    required this.onCompleted,
    this.onSyncSuccess,
  });

  @override
  State<KindleAutoSyncWidget> createState() => _KindleAutoSyncWidgetState();
}

class _KindleAutoSyncWidgetState extends State<KindleAutoSyncWidget> {
  static const String _kindleLibraryUrl =
      'https://read.amazon.com/kindle-library';
  static const String _readingInsightsUrl =
      'https://www.amazon.com/kindle/reading/insights';
  static const Duration _timeout = Duration(seconds: 60);

  final KindleWebViewService _service = KindleWebViewService();
  late final WebViewController _controller;
  Timer? _timeoutTimer;
  bool _disposed = false;
  bool _extractingBooks = false;
  bool _extractingStreaks = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
          onWebResourceError: (_) => _finish(),
        ),
      )
      ..loadRequest(Uri.parse(_kindleLibraryUrl));

    _timeoutTimer = Timer(_timeout, _finish);
  }

  @override
  void dispose() {
    _disposed = true;
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_disposed) return;
    _timeoutTimer?.cancel();
    widget.onCompleted();
  }

  Future<void> _onPageFinished(String url) async {
    if (_disposed) return;

    // Redirigé vers le login → cookies expirés → abandon
    if (url.contains('/ap/signin') || url.contains('/ap/register')) {
      debugPrint('KindleAutoSync: cookies expirés, abandon');
      _finish();
      return;
    }

    // Kindle Cloud Reader chargé → extraire les livres
    if (url.contains('read.amazon.com') && !_extractingBooks) {
      _extractingBooks = true;
      await _extractBooks();
      return;
    }

    // Reading Insights chargé → extraire les streaks
    if (url.contains('/kindle/reading/insights') && !_extractingStreaks) {
      _extractingStreaks = true;
      await Future.delayed(const Duration(seconds: 3));
      await _extractStreaks();
      return;
    }

    // Post-login redirect (page Amazon non-login) → rediriger vers la library
    if ((url.contains('amazon.com') || url.contains('amazon.fr')) &&
        !url.contains('/ap/') &&
        !_extractingBooks) {
      await _controller.loadRequest(Uri.parse(_kindleLibraryUrl));
    }
  }

  Future<void> _scrollToBottom() async {
    for (int i = 0; i < 15; i++) {
      if (_disposed) return;
      try {
        final result = await _controller.runJavaScriptReturningResult(
          KindleWebViewService.scrollStepScript,
        );
        await Future.delayed(const Duration(milliseconds: 400));
        final resultStr = result.toString();
        if (resultStr.contains('atBottom":true') ||
            resultStr.contains('atBottom:true')) {
          break;
        }
      } catch (_) {
        break;
      }
    }
    try {
      await _controller.runJavaScriptReturningResult(
        KindleWebViewService.scrollToTopScript,
      );
    } catch (_) {}
  }

  Future<bool> _waitForLibraryLoaded() async {
    for (int i = 0; i < 30; i++) {
      if (_disposed) return false;
      try {
        final result = await _controller.runJavaScriptReturningResult(
          KindleWebViewService.checkLibraryLoadedScript,
        );
        if (result.toString().contains('"loaded":true')) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> _extractBooks() async {
    try {
      await Future.delayed(const Duration(seconds: 4));
      if (_disposed) return;

      final loaded = await _waitForLibraryLoaded();
      if (_disposed) return;
      debugPrint('KindleAutoSync: library loaded=$loaded');

      await _scrollToBottom();
      if (_disposed) return;
      await Future.delayed(const Duration(seconds: 1));
      await _scrollToBottom();
      if (_disposed) return;
      await Future.delayed(const Duration(seconds: 1));

      final result = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractKindleLibraryScript,
      );

      final books = _service.parseKindleLibraryResult(result.toString());
      debugPrint('KindleAutoSync: ${books.length} livres extraits');

      if (books.isNotEmpty) {
        final tempData = KindleReadingData(books: books);
        await _service.saveLocally(tempData);

        final booksService = BooksService();
        final imported = await booksService.importKindleBooks(books);
        debugPrint('KindleAutoSync: $imported nouveaux livres importés');
      }

      // Continuer vers Reading Insights pour les streaks
      if (!_disposed) {
        await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
      }
    } catch (e) {
      debugPrint('KindleAutoSync: erreur extraction livres: $e');
      // Tenter quand même les streaks
      if (!_disposed) {
        await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
      }
    }
  }

  Future<void> _extractStreaks() async {
    try {
      await _scrollToBottom();
      if (_disposed) return;
      await Future.delayed(const Duration(seconds: 1));

      final result = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractionScript,
      );

      final data = _service.parseExtractionResult(result.toString());

      // Marquer les livres terminés
      if (data != null && data.books.isNotEmpty) {
        final booksService = BooksService();
        await booksService.markBooksAsFinished(data.books);
      }

      // Construire les données finales
      final cachedData = await _service.loadFromCache();
      final existingBooks = cachedData?.books ?? [];

      final finalData = KindleReadingData(
        booksReadThisYear: data?.booksReadThisYear,
        currentStreak: data?.currentStreak,
        weeksStreak: data?.weeksStreak,
        daysStreak: data?.daysStreak,
        longestStreak: data?.longestStreak,
        totalDaysRead: data?.totalDaysRead,
        totalMinutesRead: data?.totalMinutesRead,
        books: existingBooks,
      );

      await _service.saveLocally(finalData);
      try {
        await _service.saveToSupabase(finalData);
      } catch (e) {
        debugPrint('KindleAutoSync: Supabase save failed: $e');
      }

      debugPrint('KindleAutoSync: sync terminé avec succès');
      if (!_disposed) {
        widget.onSyncSuccess?.call(finalData);
      }
    } catch (e) {
      debugPrint('KindleAutoSync: erreur extraction streaks: $e');
    } finally {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    // WebView cachée : nécessaire pour l'exécution JS
    // mais invisible pour l'utilisateur
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

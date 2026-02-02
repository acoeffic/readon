import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/kindle_webview_service.dart';
import '../../services/books_service.dart';
import '../../theme/app_theme.dart';

class KindleLoginPage extends StatefulWidget {
  const KindleLoginPage({super.key});

  @override
  State<KindleLoginPage> createState() => _KindleLoginPageState();
}

class _KindleLoginPageState extends State<KindleLoginPage> {
  final KindleWebViewService _service = KindleWebViewService();
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _loginDetected = false;
  bool _extractingData = false;
  String _statusMessage = 'Chargement...';

  // Étape 1 : Kindle Cloud Reader pour les livres
  static const String _kindleLibraryUrl =
      'https://read.amazon.com/kindle-library';

  // Étape 2 : Reading Insights pour le streak
  static const String _readingInsightsUrl =
      'https://www.amazon.com/kindle/reading/insights';

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
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) => _onPageFinished(url),
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _statusMessage = 'Erreur: ${error.description}';
              });
            }
          },
        ),
      )
      // Commencer par la bibliothèque Kindle Cloud Reader
      ..loadRequest(Uri.parse(_kindleLibraryUrl));
  }

  Future<void> _onPageFinished(String url) async {
    if (mounted) setState(() => _isLoading = false);

    // Cas 1 : redirigé vers la page de login Amazon
    if (url.contains('/ap/signin') || url.contains('/ap/register')) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Connectez-vous à votre compte Amazon';
        });
      }
      return;
    }

    // Cas 2 : on est sur Kindle Cloud Reader (bibliothèque)
    if (url.contains('read.amazon.com')) {
      if (!_extractingData) {
        setState(() {
          _loginDetected = true;
          _extractingData = true;
          _statusMessage = 'Bibliothèque Kindle détectée...';
        });

        // Attendre que la page se charge complètement
        await Future.delayed(const Duration(seconds: 4));
        await _extractBooks();
      }
      return;
    }

    // Cas 3 : on est sur Reading Insights (étape streak)
    if (url.contains('/kindle/reading/insights')) {
      if (_extractingData) {
        await Future.delayed(const Duration(seconds: 3));
        await _extractStreaks();
      }
      return;
    }

    // Cas 4 : post-login, redirigé vers une page Amazon (pas login, pas library)
    if ((url.contains('amazon.com') || url.contains('amazon.fr')) &&
        !url.contains('/ap/')) {
      if (!_loginDetected) {
        setState(() {
          _loginDetected = true;
          _statusMessage = 'Connexion réussie ! Redirection...';
        });

        await Future.delayed(const Duration(seconds: 1));
        await _controller.loadRequest(Uri.parse(_kindleLibraryUrl));
      }
    }
  }

  /// Scroll progressif depuis Dart (compatible iOS)
  Future<void> _scrollToBottom() async {
    for (int i = 0; i < 20; i++) {
      try {
        final result = await _controller.runJavaScriptReturningResult(
          KindleWebViewService.scrollStepScript,
        );
        await Future.delayed(const Duration(milliseconds: 400));
        // Vérifier si on est en bas
        final resultStr = result.toString();
        if (resultStr.contains('atBottom":true') || resultStr.contains('atBottom:true')) break;
      } catch (_) {
        break;
      }
    }
    // Remonter en haut
    try {
      await _controller.runJavaScriptReturningResult(
        KindleWebViewService.scrollToTopScript,
      );
    } catch (_) {}
  }

  /// Attendre que la bibliothèque se charge (polling Dart)
  Future<bool> _waitForLibraryLoaded() async {
    for (int i = 0; i < 30; i++) { // 30 * 500ms = 15s max
      try {
        final result = await _controller.runJavaScriptReturningResult(
          KindleWebViewService.checkLibraryLoadedScript,
        );
        debugPrint('Kindle check ($i): $result');
        final resultStr = result.toString();
        if (resultStr.contains('"loaded":true')) return true;
      } catch (e) {
        debugPrint('Kindle check error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Étape 1 : Extraire les livres depuis Kindle Cloud Reader
  Future<void> _extractBooks() async {
    try {
      if (mounted) {
        setState(() => _statusMessage = 'Attente du chargement...');
      }

      // Attendre que la SPA charge les livres (poll synchrone depuis Dart)
      final loaded = await _waitForLibraryLoaded();
      debugPrint('Kindle Library loaded: $loaded');

      if (mounted) {
        setState(() => _statusMessage = 'Chargement de la bibliothèque...');
      }

      // Scroller pour charger tous les livres (lazy loading)
      await _scrollToBottom();
      await Future.delayed(const Duration(seconds: 1));

      // Deuxième passe de scroll
      await _scrollToBottom();
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() => _statusMessage = 'Extraction des livres...');
      }

      // Extraire les livres
      final result = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractKindleLibraryScript,
      );
      debugPrint('=== KINDLE LIBRARY RESULT ===');
      debugPrint(result.toString());

      var books = _service.parseKindleLibraryResult(result.toString());
      debugPrint('Kindle Library: ${books.length} livres extraits');

      if (books.isNotEmpty) {
        // Sauvegarder en cache local (sera utilisé par _extractStreaks)
        final tempData = KindleReadingData(books: books);
        await _service.saveLocally(tempData);

        // Détecter si c'est le premier sync Kindle
        final lastSync = await _service.getLastSyncDate();
        final isFirstSync = lastSync == null;

        // Importer dans la bibliothèque Supabase
        if (mounted) {
          setState(() => _statusMessage = '${books.length} livres trouvés. Import...');
        }

        final booksService = BooksService();
        final imported = await booksService.importKindleBooks(books, isFirstSync: isFirstSync);
        debugPrint('Kindle: $imported nouveaux livres importés (firstSync: $isFirstSync)');

        if (mounted) {
          setState(() => _statusMessage = '${books.length} livres récupérés ! Streaks...');
        }
      } else {
        if (mounted) {
          setState(() => _statusMessage = 'Aucun livre trouvé. Streaks...');
        }
      }

      // Étape 2 : Naviguer vers Reading Insights pour les streaks
      await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
    } catch (e) {
      debugPrint('Kindle library extraction error: $e');
      // En cas d'erreur, tenter quand même les streaks
      if (mounted) {
        setState(() => _statusMessage = 'Erreur livres. Streaks...');
      }
      await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
    }
  }

  /// Étape 2 : Extraire les streaks depuis Reading Insights
  Future<void> _extractStreaks() async {
    try {
      if (mounted) {
        setState(() => _statusMessage = 'Extraction des streaks...');
      }

      // Scroller pour charger le contenu
      await _scrollToBottom();
      await Future.delayed(const Duration(seconds: 1));

      // Extraire les données de streak
      final result = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractionScript,
      );
      debugPrint('=== KINDLE STREAK RESULT ===');
      debugPrint(result.toString());

      final data = _service.parseExtractionResult(result.toString());

      // Marquer comme terminés les livres trouvés sur Reading Insights
      if (data != null && data.books.isNotEmpty) {
        final booksService = BooksService();
        final markedFinished = await booksService.markBooksAsFinished(data.books);
        debugPrint('Kindle: $markedFinished livres marqués comme terminés');
      }

      // Charger les livres déjà extraits du cache (étape 1)
      final cachedData = await _service.loadFromCache();
      final existingBooks = cachedData?.books ?? [];

      // Construire les données finales avec streaks + livres
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

      // Sauvegarder
      await _service.saveLocally(finalData);
      try {
        await _service.saveToSupabase(finalData);
      } catch (e) {
        debugPrint('Kindle: Supabase save failed (non-critical): $e');
      }

      if (mounted) {
        final streakInfo = data?.daysStreak != null
            ? ' | Streak: ${data!.daysStreak} jours'
            : '';
        setState(() {
          _statusMessage = '${existingBooks.length} livres$streakInfo';
          _extractingData = false;
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, finalData);
        }
      }
    } catch (e) {
      debugPrint('Kindle streak extraction error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Erreur streaks: $e';
          _extractingData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion Kindle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_extractingData)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.l,
              vertical: AppSpace.s,
            ),
            color: _loginDetected
                ? AppColors.primary.withValues(alpha:0.1)
                : Colors.orange.withValues(alpha:0.1),
            child: Row(
              children: [
                Icon(
                  _loginDetected ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: _loginDetected ? AppColors.primary : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _loginDetected ? AppColors.primary : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading) const LinearProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

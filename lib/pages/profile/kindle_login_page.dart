import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/kindle_webview_service.dart';
import '../../services/books_service.dart';
import '../../theme/app_theme.dart';

/// Étapes visibles du sync Kindle
enum _SyncPhase {
  login,       // L'utilisateur se connecte sur Amazon
  connecting,  // Post-login, redirection en cours
  syncing,     // Extraction parallèle (library + insights)
  importing,   // Import dans Supabase
  done,        // Terminé
  error,       // Erreur avec possibilité de retry
}

class KindleLoginPage extends StatefulWidget {
  const KindleLoginPage({super.key});

  @override
  State<KindleLoginPage> createState() => _KindleLoginPageState();
}

class _KindleLoginPageState extends State<KindleLoginPage>
    with SingleTickerProviderStateMixin {
  final KindleWebViewService _service = KindleWebViewService();
  late final AnimationController _pulseController;

  // WebView principale (login → library)
  late final WebViewController _libraryController;
  // WebView secondaire (insights, en parallèle)
  late final WebViewController _insightsController;

  _SyncPhase _phase = _SyncPhase.login;
  bool _isLoading = true;
  int _booksFound = 0;
  String? _errorMessage;
  bool _parallelStarted = false;
  bool _finalized = false;
  Timer? _timeoutTimer;

  // Timeout global : 60s après le début de l'extraction
  static const Duration _extractionTimeout = Duration(seconds: 60);

  // Résultats des extractions parallèles
  List<KindleBookProgress>? _libraryBooks;
  KindleReadingData? _insightsData;

  // URLs
  static const String _kindleLibraryUrl =
      'https://read.amazon.com/kindle-library';
  static const String _readingInsightsUrl =
      'https://www.amazon.com/kindle/reading/insights';

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // WebView principale : login puis library
    _libraryController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) => _onLibraryPageFinished(url),
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_kindleLibraryUrl));

    // WebView secondaire : sera lancée après login pour insights
    _insightsController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) => _onInsightsPageFinished(url),
          onWebResourceError: (_) {
            // Insights en erreur → on continue sans
            debugPrint('Kindle insights webview error');
          },
        ),
      );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Navigation handlers ──────────────────────────────────────────

  Future<void> _onLibraryPageFinished(String url) async {
    if (mounted) setState(() => _isLoading = false);

    // Cas 1 : page de login Amazon
    if (url.contains('/ap/signin') || url.contains('/ap/register')) {
      if (mounted) setState(() => _phase = _SyncPhase.login);
      return;
    }

    // Cas 2 : Kindle Cloud Reader → lancer l'extraction parallèle
    if (url.contains('read.amazon.com')) {
      if (_phase == _SyncPhase.login || _phase == _SyncPhase.connecting) {
        setState(() => _phase = _SyncPhase.syncing);
        _startParallelExtraction();
      }
      return;
    }

    // Cas 3 : Reading Insights (redirigé après login)
    if (url.contains('/kindle/reading/insights')) {
      if (_phase == _SyncPhase.login) {
        setState(() => _phase = _SyncPhase.connecting);
        await _libraryController.loadRequest(Uri.parse(_kindleLibraryUrl));
      }
      return;
    }

    // Cas 4 : post-login, page Amazon quelconque
    if ((url.contains('amazon.com') || url.contains('amazon.fr')) &&
        !url.contains('/ap/')) {
      if (_phase == _SyncPhase.login) {
        setState(() => _phase = _SyncPhase.connecting);
        await _libraryController.loadRequest(Uri.parse(_kindleLibraryUrl));
      }
    }
  }

  Future<void> _onInsightsPageFinished(String url) async {
    // On attend que la page insights se charge pour extraire
    if (url.contains('/kindle/reading/insights')) {
      await Future.delayed(const Duration(milliseconds: 800));
      await _extractInsights();
    }
  }

  // ─── Extraction parallèle ─────────────────────────────────────────

  /// Lance les deux extractions en parallèle
  void _startParallelExtraction() {
    if (_parallelStarted) return;
    _parallelStarted = true;

    // Timeout de sécurité
    _timeoutTimer = Timer(_extractionTimeout, _onTimeout);

    // Lancer insights dans la WebView secondaire (cookies partagés)
    _insightsController.loadRequest(Uri.parse(_readingInsightsUrl));

    // Lancer library dans la WebView principale
    _extractLibrary();
  }

  /// Timeout : finaliser avec ce qu'on a, ou afficher une erreur
  void _onTimeout() {
    if (!mounted || _finalized) return;
    debugPrint('Kindle: extraction timeout after ${_extractionTimeout.inSeconds}s');

    // Si on a des livres, on finalise avec les données partielles
    if (_libraryBooks != null && _libraryBooks!.isNotEmpty) {
      _insightsData ??= KindleReadingData();
      _tryFinalize();
    } else {
      setState(() {
        _phase = _SyncPhase.error;
        _errorMessage = null; // Le message d'erreur est géré par _getPhaseTitle
      });
    }
  }

  /// Réinitialiser et relancer l'extraction
  void _retry() {
    setState(() {
      _phase = _SyncPhase.login;
      _parallelStarted = false;
      _finalized = false;
      _libraryBooks = null;
      _insightsData = null;
      _booksFound = 0;
      _errorMessage = null;
    });
    _timeoutTimer?.cancel();
    _libraryController.loadRequest(Uri.parse(_kindleLibraryUrl));
  }

  /// Scroll progressif avec early termination
  Future<void> _scrollToBottom(
    WebViewController controller, {
    bool scrollBack = true,
  }) async {
    int noChangeCount = 0;
    String lastResult = '';

    for (int i = 0; i < 30; i++) {
      try {
        final result = await controller.runJavaScriptReturningResult(
          KindleWebViewService.scrollStepScript,
        );
        await Future.delayed(const Duration(milliseconds: 100));
        final resultStr = result.toString();

        if (resultStr.contains('atBottom":true') ||
            resultStr.contains('atBottom:true')) break;

        if (resultStr == lastResult) {
          noChangeCount++;
          if (noChangeCount >= 3) break;
        } else {
          noChangeCount = 0;
        }
        lastResult = resultStr;
      } catch (_) {
        break;
      }
    }
    if (scrollBack) {
      try {
        await controller.runJavaScriptReturningResult(
          KindleWebViewService.scrollToTopScript,
        );
      } catch (_) {}
    }
  }

  /// Polling rapide pour détecter le chargement de la library
  Future<bool> _waitForLibraryLoaded() async {
    for (int i = 0; i < 25; i++) {
      try {
        final result = await _libraryController.runJavaScriptReturningResult(
          KindleWebViewService.checkLibraryLoadedScript,
        );
        debugPrint('Kindle check ($i): $result');
        if (result.toString().contains('"loaded":true')) return true;
      } catch (e) {
        debugPrint('Kindle check error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// Extraction de la bibliothèque (WebView principale)
  Future<void> _extractLibrary() async {
    try {
      await _waitForLibraryLoaded();
      await _scrollToBottom(_libraryController);
      await Future.delayed(const Duration(milliseconds: 300));

      final result = await _libraryController.runJavaScriptReturningResult(
        KindleWebViewService.extractKindleLibraryScript,
      );
      debugPrint('=== KINDLE LIBRARY RESULT ===');
      debugPrint(result.toString());

      final books = _service.parseKindleLibraryResult(result.toString());
      debugPrint('Kindle Library: ${books.length} livres extraits');

      _libraryBooks = books;

      if (mounted) {
        setState(() => _booksFound = books.length);
      }

      // Vérifier si les deux extractions sont terminées
      _tryFinalize();
    } catch (e) {
      debugPrint('Kindle library extraction error: $e');
      _libraryBooks = []; // Vide en cas d'erreur
      _tryFinalize();
    }
  }

  /// Extraction des insights (WebView secondaire)
  Future<void> _extractInsights() async {
    try {
      await _scrollToBottom(_insightsController, scrollBack: false);
      await Future.delayed(const Duration(milliseconds: 200));

      final result = await _insightsController.runJavaScriptReturningResult(
        KindleWebViewService.extractionScript,
      );
      debugPrint('=== KINDLE INSIGHTS RESULT ===');
      debugPrint(result.toString());

      _insightsData = _service.parseExtractionResult(result.toString());
      debugPrint('Kindle Insights: streaks=${_insightsData?.daysStreak}');

      _tryFinalize();
    } catch (e) {
      debugPrint('Kindle insights extraction error: $e');
      _insightsData = KindleReadingData(); // Vide en cas d'erreur
      _tryFinalize();
    }
  }

  /// Appelée quand une extraction se termine — finalise si les deux sont prêtes
  Future<void> _tryFinalize() async {
    // Attendre que les DEUX extractions soient terminées
    if (_libraryBooks == null || _insightsData == null) return;
    // Guard contre les appels multiples
    if (_finalized) return;
    _finalized = true;
    _timeoutTimer?.cancel();

    if (mounted) setState(() => _phase = _SyncPhase.importing);

    final books = _libraryBooks!;
    final insights = _insightsData;

    try {
      // Import des livres dans Supabase
      if (books.isNotEmpty) {
        final tempData = KindleReadingData(books: books);
        await _service.saveLocally(tempData);

        final lastSync = await _service.getLastSyncDate();
        final isFirstSync = lastSync == null;

        final booksService = BooksService();
        final imported = await booksService.importKindleBooks(
          books,
          isFirstSync: isFirstSync,
        );
        debugPrint('Kindle: $imported nouveaux livres importés (firstSync: $isFirstSync)');
      }

      // Marquer les livres terminés depuis insights
      if (insights != null && insights.books.isNotEmpty) {
        final booksService = BooksService();
        await booksService.markBooksAsFinished(insights.books);
      }

      // Construire les données finales
      final finalData = KindleReadingData(
        booksReadThisYear: insights?.booksReadThisYear,
        currentStreak: insights?.currentStreak,
        weeksStreak: insights?.weeksStreak,
        daysStreak: insights?.daysStreak,
        longestStreak: insights?.longestStreak,
        totalDaysRead: insights?.totalDaysRead,
        totalMinutesRead: insights?.totalMinutesRead,
        books: books,
      );

      await _service.saveLocally(finalData);
      try {
        await _service.saveToSupabase(finalData);
      } catch (e) {
        debugPrint('Kindle: Supabase save failed (non-critical): $e');
      }

      if (mounted) {
        setState(() {
          _booksFound = books.length;
          _phase = _SyncPhase.done;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, finalData);
      }
    } catch (e) {
      debugPrint('Kindle finalization error: $e');
      // Retourner quand même ce qu'on a
      if (books.isNotEmpty && mounted) {
        final partialData = KindleReadingData(books: books);
        setState(() => _phase = _SyncPhase.done);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, partialData);
      } else if (mounted) {
        setState(() {
          _phase = _SyncPhase.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────

  bool get _showWebView => _phase == _SyncPhase.login;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kindleLoginTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // WebView principale (login → library) — visible pendant le login
          Positioned.fill(
            child: Offstage(
              offstage: !_showWebView,
              child: Column(
                children: [
                  _buildTrustBanner(l10n),
                  Expanded(
                    child: Stack(
                      children: [
                        WebViewWidget(controller: _libraryController),
                        if (_isLoading) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // WebView secondaire (insights) — toujours cachée
          Offstage(
            offstage: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: WebViewWidget(controller: _insightsController),
            ),
          ),

          // Overlay de progression
          if (!_showWebView) _buildProgressOverlay(l10n),
        ],
      ),
    );
  }

  /// Bandeau de réassurance affiché pendant le login Amazon
  Widget _buildTrustBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.s + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 15,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.kindleTrustBanner,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary.withValues(alpha: 0.9),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Overlay de progression avec stepper animé
  Widget _buildProgressOverlay(AppLocalizations l10n) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icône animée
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + _pulseController.value * 0.08;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _phase == _SyncPhase.done
                        ? Icons.check_rounded
                        : _phase == _SyncPhase.error
                            ? Icons.refresh_rounded
                            : Icons.menu_book_rounded,
                    color: _phase == _SyncPhase.error
                        ? Colors.orange
                        : AppColors.primary,
                    size: 42,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Compteur de livres
              if (_booksFound > 0) ...[
                Text(
                  '$_booksFound',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.kindleBooksFound(_booksFound),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Message principal
              Text(
                _getPhaseTitle(l10n),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _getPhaseSubtitle(l10n),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              // Stepper horizontal
              _buildStepper(l10n),

              // Bouton Réessayer en cas d'erreur
              if (_phase == _SyncPhase.error) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(
                      l10n.kindleRetryButton,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  /// Stepper horizontal montrant la progression
  Widget _buildStepper(AppLocalizations l10n) {
    final steps = [
      (l10n.kindleStepLibrary, _SyncPhase.syncing),
      (l10n.kindleStepImport, _SyncPhase.importing),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 32,
              height: 2,
              color: _isStepDone(steps[i].$2)
                  ? AppColors.primary
                  : Colors.black12,
            ),
          _buildStepDot(steps[i].$1, steps[i].$2),
        ],
      ],
    );
  }

  Widget _buildStepDot(String label, _SyncPhase stepPhase) {
    final done = _isStepDone(stepPhase);
    final active = _isStepActive(stepPhase);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 28 : 22,
          height: active ? 28 : 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.primary
                : active
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.06),
            border: active && !done
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : active
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: done || active ? AppColors.primary : Colors.black38,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  bool _isStepDone(_SyncPhase stepPhase) {
    const order = [
      _SyncPhase.login,
      _SyncPhase.connecting,
      _SyncPhase.syncing,
      _SyncPhase.importing,
      _SyncPhase.done,
    ];
    return order.indexOf(_phase) > order.indexOf(stepPhase);
  }

  bool _isStepActive(_SyncPhase stepPhase) => _phase == stepPhase;

  String _getPhaseTitle(AppLocalizations l10n) {
    switch (_phase) {
      case _SyncPhase.login:
        return l10n.kindlePhaseLoginTitle;
      case _SyncPhase.connecting:
        return l10n.kindlePhaseConnectingTitle;
      case _SyncPhase.syncing:
        return l10n.kindlePhaseLibraryTitle;
      case _SyncPhase.importing:
        return l10n.kindlePhaseImportingTitle;
      case _SyncPhase.done:
        return l10n.kindlePhaseDoneTitle;
      case _SyncPhase.error:
        return l10n.kindlePhaseErrorTitle;
    }
  }

  String _getPhaseSubtitle(AppLocalizations l10n) {
    switch (_phase) {
      case _SyncPhase.login:
        return l10n.kindlePhaseLoginSubtitle;
      case _SyncPhase.connecting:
        return l10n.kindlePhaseConnectingSubtitle;
      case _SyncPhase.syncing:
        return l10n.kindlePhaseLibrarySubtitle;
      case _SyncPhase.importing:
        return l10n.kindlePhaseImportingSubtitle;
      case _SyncPhase.done:
        return l10n.kindlePhaseDoneSubtitle;
      case _SyncPhase.error:
        return l10n.kindlePhaseErrorSubtitle;
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/analytics_service.dart';
import '../services/kindle_webview_service.dart';
import '../services/kindle_auto_sync_service.dart';
import '../services/books_service.dart';
import '../services/kindle_background_sync.dart';
import '../services/kindle_cookie_store.dart';

/// Widget invisible qui effectue un sync Kindle en arrière-plan.
/// Utilise une WebView cachée (Offstage) pour extraire les données
/// Amazon via les cookies persistants d'une connexion précédente.
///
/// Découpage du pipeline (important) :
///
///   phase WEBVIEW (sous chrono `_webViewTimeout`)
///     1. charger read.amazon.com/kindle-library → extraire la liste de livres
///     2. charger amazon.com/kindle/reading/insights → extraire les streaks
///   phase HIGHLIGHTS (sous son propre chrono `_highlightsTimeout`)
///     3. charger read.amazon.com/notebook → crawl AJAX des surlignages
///        (best-effort : un échec ici ne fait JAMAIS échouer le sync)
///   phase FINALISATION (sous chrono `_finalizeTimeout`, plus de WebView)
///     4. importKindleBooks() puis markBooksAsFinished() vers Supabase
///     5. importKindleHighlights() → annotations type 'kindle' (Mes passages)
///     6. persistance du cache + `kindle_last_sync` + saveToSupabase
///
/// Avant, l'import Supabase (2 à 4 requêtes PAR LIVRE) était dans la phase 1,
/// donc dans le budget du chrono : au-delà d'une vingtaine de livres le timeout
/// tombait pendant l'import, la WebView était détruite et les streaks n'étaient
/// jamais extraites. Pire, `saveLocally()` était appelé à mi-parcours avec des
/// streaks nulles, ce qui écrasait le cache ET posait `kindle_last_sync = now`
/// → l'auto-sync se rendormait 24 h en croyant avoir réussi. La feature se
/// cassait donc toute seule, en boucle, sur toute bibliothèque un peu fournie.
/// Étendue d'un passage du widget.
enum KindleSyncMode {
  /// Bibliothèque + streaks + surlignages + progression (verrou 24 h).
  full,

  /// Progression seule : endpoint JSON (ASIN) puis GET HTML des livres
  /// récents, import des deltas → sessions. Aucune écriture de
  /// `kindle_last_sync`, pas de SnackBar « synchronisé ». Lancé à chaque
  /// retour au premier plan (espacement 1 h) — voir
  /// `KindleAutoSyncService.shouldProgressSync`.
  progressOnly,
}

class KindleAutoSyncWidget extends StatefulWidget {
  final VoidCallback onCompleted;
  final void Function(KindleReadingData data)? onSyncSuccess;
  final KindleSyncMode mode;

  /// Des sessions ont été créées depuis la progression Kindle (nombre).
  final void Function(int count)? onKindleSessionsCreated;

  /// Appelé quand la WebView est redirigée vers le login Amazon :
  /// les cookies ont expiré, l'utilisateur doit se reconnecter.
  final VoidCallback? onCookiesExpired;

  const KindleAutoSyncWidget({
    super.key,
    required this.onCompleted,
    this.onSyncSuccess,
    this.onCookiesExpired,
    this.onKindleSessionsCreated,
    this.mode = KindleSyncMode.full,
  });

  @override
  State<KindleAutoSyncWidget> createState() => _KindleAutoSyncWidgetState();
}

class _KindleAutoSyncWidgetState extends State<KindleAutoSyncWidget> {
  static const String _kindleLibraryUrl =
      'https://read.amazon.com/kindle-library';

  /// Point d'entrée du sync : l'endpoint JSON de la bibliothèque, chargé
  /// DIRECTEMENT comme page. Quelques Ko de JSON au lieu de l'app Ionic
  /// complète de `/kindle-library` (plusieurs Mo, rendu en 5-15 s), et les
  /// mêmes redirections `/ap/signin` quand la session est expirée. La page
  /// `/kindle-library` n'est plus chargée que pour le repli DOM.
  static const String _kindleLibraryJsonUrl =
      'https://read.amazon.com/kindle-library/search'
      '?query=&libraryType=BOOKS&sortType=recency&querySize=50';
  static const String _readingInsightsUrl =
      'https://www.amazon.com/kindle/reading/insights';
  static const String _notebookUrl = 'https://read.amazon.com/notebook';

  /// Budget de la phase WebView UNIQUEMENT (chargement de page + scrolls + JS).
  /// L'import Supabase se fait après, sous son propre chrono : sa durée dépend
  /// du nombre de livres et n'a aucune raison de faire échouer le sync.
  static const Duration _webViewTimeout = Duration(seconds: 90);

  /// Chien de garde de la phase de finalisation. `postgrest` et `http`
  /// n'appliquent aucun timeout par défaut : sans ce garde-fou, une requête
  /// pendue (réseau qui bascule, portail captif) laisserait `onCompleted()`
  /// jamais appelé, donc le widget monté à vie — et `MainNavigation` sort en
  /// early-return tant qu'il l'est, ce qui bloquerait tout sync ultérieur
  /// jusqu'au redémarrage de l'app.
  static const Duration _finalizeTimeout = Duration(minutes: 5);

  /// Budget de la phase highlights (crawl AJAX de read.amazon.com/notebook).
  /// Hors du budget `_webViewTimeout` : les streaks sont déjà extraites quand
  /// cette phase démarre, elle ne peut donc rien faire perdre. À l'échéance,
  /// on collecte ce qui a été accumulé (la dédup par `source_key` rend un
  /// résultat partiel inoffensif — le reste arrivera au sync suivant).
  static const Duration _highlightsTimeout = Duration(seconds: 75);

  /// Taille des tranches de collecte des surlignages depuis la WebView.
  static const int _highlightsChunkSize = 150;

  /// Plafond dur, aligné sur MAX_HIGHLIGHTS du script JS.
  static const int _maxHighlightsPerSync = 2000;

  /// Phase 4 : progression. `percentageRead` de l'API JSON est toujours 0
  /// (vérifié en réel le 10/09/2026), donc on ouvre le Cloud Reader des
  /// [_maxReaderProgressBooks] livres les plus récents (ordre de l'API =
  /// récence) et on lit le pied de page « Page X of Y ● Z% ». Budget par
  /// livre : [_readerProgressTimeout]. Best-effort, tourne au début de
  /// `_finalize` tant que la WebView est vivante.
  static const int _maxReaderProgressBooks = 3;
  static const Duration _readerProgressTimeout = Duration(seconds: 20);

  /// Voie par défaut de la phase 4 : GET du HTML du lecteur (position rendue
  /// côté serveur, ~1 s/livre, aucun rendu). Couvre plus de livres que le
  /// repli WebView.
  static const int _maxHtmlProgressBooks = 10;

  /// Plafond total après ajout des livres « en cours » côté LexDay.
  static const int _maxHtmlProgressBooksTotal = 25;

  /// Viewport de la WebView cachée (voir `build`).
  static const Size _hiddenViewportSize = Size(390, 844);

  final KindleWebViewService _service = KindleWebViewService();
  final KindleAutoSyncService _autoSyncService = KindleAutoSyncService();
  late final WebViewController _controller;
  Timer? _timeoutTimer;
  Timer? _finalizeWatchdog;
  bool _disposed = false;
  bool _extractingBooks = false;
  bool _extractingBooksDom = false;
  bool _extractingStreaks = false;
  bool _extractingHighlights = false;

  /// Vrai dès que la navigation vers le notebook est lancée. Sert à ne PAS
  /// interpréter une redirection login sur CETTE page comme une session
  /// expirée : Amazon peut exiger une ré-authentification pour le notebook
  /// alors que les cookies restent valides pour la bibliothèque — le sync
  /// principal, lui, vient de réussir.
  bool _highlightsPhaseStarted = false;
  bool _finalizing = false;
  bool _completedCalled = false;
  bool _sessionExpired = false;

  /// Résultats des phases d'extraction, consommés par `_finalize()`.
  List<KindleBookProgress>? _extractedBooks;
  KindleReadingData? _extractedStreaks;

  /// Calendrier de lecture Amazon (jours lus), pour dater les sessions.
  KindleInsightsCalendar? _calendar;

  /// Phase progression déjà jouée (avant les surlignages, pour piloter le
  /// crawl incrémental) : `_finalize` ne la rejoue pas.
  bool _progressDone = false;

  /// Vrai pendant la phase progression hors `_finalize` : ses navigations
  /// (endpoint JSON, éventuellement le lecteur) ne doivent rien déclencher
  /// dans `_onPageFinished`.
  bool _progressPhaseActive = false;

  /// Filtre d'ASIN du crawl notebook (`null` = tous les livres).
  List<String>? _highlightAsinsFilter;
  bool _highlightFullCrawl = false;
  List<KindleHighlight>? _extractedHighlights;

  bool get _progressOnly => widget.mode == KindleSyncMode.progressOnly;

  @override
  void initState() {
    super.initState();
    if (_progressOnly) {
      // Le mini-sync ne touche ni au backoff du sync complet ni au flag
      // surlignages : il a son propre espacement.
      unawaited(
        _autoSyncService.recordProgressAttempt().catchError(
          (Object e) =>
              debugPrint('KindleAutoSync: recordProgressAttempt failed: $e'),
        ),
      );
    } else {
      // Trace la tentative même si elle échoue : sans ça, un échec ne laissait
      // aucune trace et l'auto-sync se relançait à chaque retour au premier
      // plan (seulement limité par le cooldown mémoire de 5 min de
      // MainNavigation, remis à zéro à chaque redémarrage de l'app).
      unawaited(
        _autoSyncService.recordAttempt().catchError(
          (Object e) => debugPrint('KindleAutoSync: recordAttempt failed: $e'),
        ),
      );

      // Consommé au DÉMARRAGE, pas à la réussite : le flag « surlignages en
      // attente » bypasse le verrou 24 h ET le backoff dans shouldAutoSync —
      // le laisser posé après un échec relancerait une WebView à chaque
      // retour au premier plan. Une tentative garantie, puis régime normal.
      unawaited(
        _autoSyncService.clearHighlightsPending().catchError(
          (Object e) =>
              debugPrint('KindleAutoSync: clearHighlightsPending failed: $e'),
        ),
      );
    }

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
          onWebResourceError: _onWebResourceError,
        ),
      )
      ..loadRequest(Uri.parse(_kindleLibraryJsonUrl));

    _timeoutTimer = Timer(_webViewTimeout, () {
      debugPrint('KindleAutoSync: timeout phase WebView');
      _finalize(reason: 'timeout');
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timeoutTimer?.cancel();
    _finalizeWatchdog?.cancel();
    super.dispose();
  }

  void _onWebResourceError(WebResourceError error) {
    // Sur Android, onReceivedError remonte AUSSI les sous-ressources (images,
    // trackers, beacons publicitaires) : une seule pub bloquée sur une page
    // Amazon suffisait à annuler tout le sync.
    if (!(error.isForMainFrame ?? true)) return;

    // -999 = NSURLErrorCancelled : WKWebView le remonte quand on remplace une
    // navigation encore en vol — ce qu'on fait volontairement en enchaînant sur
    // la page Insights. Ce n'est pas un échec.
    if (error.errorCode == -999) {
      debugPrint('KindleAutoSync: navigation annulée (attendu), on continue');
      return;
    }

    debugPrint(
      'KindleAutoSync: erreur WebView ${error.errorCode} — ${error.description}',
    );
    _finalize(reason: 'weberror');
  }

  Future<void> _onPageFinished(String url) async {
    if (_disposed || _finalizing || _progressPhaseActive) return;

    // Redirigé vers le login → cookies expirés → abandon + notif.
    // `/landing` est le cas le plus fréquent : Amazon y renvoie les visiteurs
    // non authentifiés de read.amazon.com (cf. KindleLoginPage), et comme
    // l'URL contient bien « read.amazon.com » elle était jusqu'ici prise pour
    // une bibliothèque chargée → on scrollait et on extrayait une page
    // marketing.
    if (_isSignedOutUrl(url)) {
      // Redirection login pendant la phase highlights : le sync principal
      // (bibliothèque + streaks) a déjà réussi avec ces cookies. On abandonne
      // seulement les surlignages, SANS marquer la session expirée — sinon
      // `saveLocally` serait sauté et l'utilisateur serait invité à se
      // reconnecter alors que tout fonctionne.
      if (_highlightsPhaseStarted) {
        debugPrint(
          'KindleAutoSync: login demandé sur le notebook ($url) — '
          'surlignages abandonnés, sync principal préservé',
        );
        _finalize(reason: 'ok');
        return;
      }
      debugPrint('KindleAutoSync: session Amazon expirée ($url)');
      _sessionExpired = true;
      if (!_disposed) {
        widget.onCookiesExpired?.call();
      }
      _finalize(reason: 'cookies-expired');
      return;
    }

    // Notebook chargé → crawler les surlignages. Testé AVANT la branche
    // bibliothèque : l'URL contient aussi « read.amazon.com ».
    final path = Uri.tryParse(url)?.path ?? '';
    if (path.startsWith('/notebook') && !_extractingHighlights) {
      _extractingHighlights = true;
      await _extractHighlights();
      return;
    }

    // Endpoint JSON chargé → voie rapide (pas d'attente de rendu, pas de
    // scroll). Testé AVANT la branche bibliothèque : même hôte.
    if (path.startsWith('/kindle-library/search') && !_extractingBooks) {
      _extractingBooks = true;
      await _extractBooksFast();
      return;
    }

    // Page bibliothèque chargée → repli DOM (seulement si la voie JSON a
    // échoué, c'est elle qui navigue ici).
    if (url.contains('read.amazon.com') && !_extractingBooksDom) {
      _extractingBooksDom = true;
      _extractingBooks = true;
      await _extractBooksDom();
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
      await _controller.loadRequest(Uri.parse(_kindleLibraryJsonUrl));
    }
  }

  /// Ancré sur l'hôte et le chemin : un simple `contains('/landing')` matchait
  /// aussi des pages Amazon parfaitement légitimes (`/gp/…/landing…`), ce qui
  /// aurait affiché « session expirée » à un utilisateur connecté.
  bool _isSignedOutUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path;
    if (path.startsWith('/ap/signin') || path.startsWith('/ap/register')) {
      return true;
    }
    return uri.host.contains('read.amazon.') && path.startsWith('/landing');
  }

  Future<void> _scrollToBottom() async {
    for (int i = 0; i < 15; i++) {
      if (_disposed || _finalizing) return;
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
      if (_disposed || _finalizing) return false;
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

  /// Voie rapide : l'endpoint JSON est déjà la page courante, on lance le
  /// fetch paginé tout de suite (ASIN + titres, ~1-2 s). En cas d'échec on
  /// charge la vraie page bibliothèque pour le repli DOM.
  Future<void> _extractBooksFast() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_disposed || _finalizing) return;

      final sw = Stopwatch()..start();
      final books = await _service.fetchLibraryViaJson(
        _controller,
        shouldAbort: () => _disposed || _finalizing,
      );
      if (_disposed || _finalizing) return;

      if (books.isEmpty) {
        if (_progressOnly) {
          // Sans ASIN (le DOM n'en donne pas), la progression est impossible.
          debugPrint('KindleAutoSync: progression — voie JSON vide, abandon');
          await _finalize(reason: 'json-empty');
          return;
        }
        debugPrint(
          'KindleAutoSync: voie JSON vide (${sw.elapsedMilliseconds} ms) → '
          'repli sur la page bibliothèque',
        );
        await _controller.loadRequest(Uri.parse(_kindleLibraryUrl));
        return;
      }

      debugPrint(
        'KindleAutoSync: ${books.length} livres extraits via json en '
        '${sw.elapsedMilliseconds} ms',
      );
      await _onBooksExtracted(books);
    } catch (e) {
      debugPrint('KindleAutoSync: erreur voie JSON: $e');
      if (!_disposed && !_finalizing) {
        await _controller.loadRequest(Uri.parse(_kindleLibraryUrl));
      }
    }
  }

  /// Repli DOM historique (sans ASIN ni progression) : attend le rendu de
  /// l'app bibliothèque, scrolle pour charger toutes les tuiles, scrape.
  Future<void> _extractBooksDom() async {
    try {
      await Future.delayed(const Duration(seconds: 4));
      if (_disposed || _finalizing) return;

      final loaded = await _waitForLibraryLoaded();
      if (_disposed || _finalizing) return;
      debugPrint('KindleAutoSync: library loaded=$loaded');

      // Le retour de _waitForLibraryLoaded n'était jusqu'ici que loggé : on
      // extrayait même quand la page n'avait rien d'une bibliothèque.
      if (!loaded) {
        debugPrint('KindleAutoSync: bibliothèque jamais chargée, abandon');
        _finalize(reason: 'library-not-loaded');
        return;
      }

      await _scrollToBottom();
      if (_disposed || _finalizing) return;
      await Future.delayed(const Duration(seconds: 1));
      await _scrollToBottom();
      if (_disposed || _finalizing) return;
      await Future.delayed(const Duration(seconds: 1));

      final result = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractKindleLibraryScript,
      );
      final books = _service.parseKindleLibraryResult(result.toString());
      debugPrint('KindleAutoSync: ${books.length} livres extraits via dom');

      await _onBooksExtracted(books);
    } catch (e) {
      debugPrint('KindleAutoSync: erreur extraction livres: $e');
      // Tenter quand même les streaks
      if (!_disposed && !_finalizing) {
        await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
      }
    }
  }

  /// Suite commune des deux voies : cache intermédiaire puis navigation vers
  /// Reading Insights pour les streaks. L'import Supabase est volontairement
  /// repoussé à `_finalize()`.
  Future<void> _onBooksExtracted(List<KindleBookProgress> books) async {
    if (books.isNotEmpty) {
      _extractedBooks = books;
      // Cache la liste SANS toucher à `kindle_last_sync` ni au flag
      // d'expiration : le sync n'est pas terminé, il ne doit pas compter
      // comme réussi tant que la finalisation n'a pas eu lieu.
      await _service.cacheBooksOnly(books);
    }
    if (_disposed || _finalizing) return;
    if (_progressOnly) {
      // Mini-sync : ni streaks ni surlignages, droit à la progression.
      await _finalize(reason: 'ok');
      return;
    }
    await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
  }

  Future<void> _extractStreaks() async {
    try {
      await _scrollToBottom();
      if (_disposed || _finalizing) return;
      await Future.delayed(const Duration(seconds: 1));

      final result = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractionScript,
      );

      _extractedStreaks = _service.parseExtractionResult(result.toString());
      debugPrint(
        'KindleAutoSync: streaks extraites '
        '(${_extractedStreaks?.daysStreak ?? '?'} jours)',
      );
      await _extractCalendar();
    } catch (e) {
      debugPrint('KindleAutoSync: erreur extraction streaks: $e');
    } finally {
      // Streaks en poche : on enchaîne sur les surlignages plutôt que de
      // finaliser tout de suite. Cette phase est best-effort de bout en bout.
      await _startHighlightsPhase();
    }
  }

  /// Lit le calendrier de lecture (`days_read`) dans le JSON inline de la
  /// page Insights courante. Best-effort.
  Future<void> _extractCalendar() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        KindleWebViewService.extractInsightsPreloadedDataScript,
      );
      _calendar = _service.parseInsightsPreloadedData(raw.toString());
      final last = _calendar?.daysRead.isNotEmpty == true
          ? _calendar!.daysRead.last
          : null;
      debugPrint(
        'KindleAutoSync: calendrier Amazon — '
        '${_calendar?.daysRead.length ?? 0} jours lus, dernier: $last',
      );
    } catch (e) {
      debugPrint('KindleAutoSync: calendrier Amazon KO: $e');
    }
  }

  /// Phase 3 : navigation vers read.amazon.com/notebook pour le crawl des
  /// surlignages. Tout échec ici bascule directement en finalisation avec ce
  /// qui a déjà été extrait — les highlights ne peuvent pas faire échouer un
  /// sync qui, sans eux, aurait réussi.
  Future<void> _startHighlightsPhase() async {
    if (_finalizing) return;
    if (_disposed || _sessionExpired) {
      await _finalize(reason: 'ok');
      return;
    }
    try {
      // Progression AVANT les surlignages : elle dit quels livres ont bougé,
      // donc lesquels recrawler. Pur fetch (~10 s), sans chrono externe.
      _timeoutTimer?.cancel();
      _progressPhaseActive = true;
      try {
        await _extractReaderProgress();
        _progressDone = true;
      } catch (e) {
        debugPrint('KindleAutoSync: phase progression (pré-notebook) KO: $e');
      } finally {
        _progressPhaseActive = false;
      }
      if (_disposed || _finalizing) return;
      await _planHighlightCrawl();

      // Le budget WebView de la phase 1-2 est consommé à un point inconnu :
      // on le remplace par un chrono propre à cette phase (+ marge pour le
      // chargement de la page). S'il tombe, `_finalize` collecte ce qu'on a.
      _timeoutTimer = Timer(
        _highlightsTimeout + const Duration(seconds: 20),
        () {
          debugPrint('KindleAutoSync: timeout phase highlights');
          _finalize(reason: 'highlights-timeout');
        },
      );
      _highlightsPhaseStarted = true;
      await _controller.loadRequest(Uri.parse(_notebookUrl));
    } catch (e) {
      debugPrint('KindleAutoSync: navigation notebook impossible: $e');
      await _finalize(reason: 'ok');
    }
  }

  /// Décide quels livres recrawler : tous si un passage complet est dû
  /// (jamais fait / > 7 jours), sinon les livres dont la progression a bougé
  /// + ceux jamais crawlés (nouveaux dans la bibliothèque).
  Future<void> _planHighlightCrawl() async {
    _highlightAsinsFilter = null;
    _highlightFullCrawl = true;
    try {
      if (await _autoSyncService.isFullHighlightCrawlDue()) {
        debugPrint('KindleAutoSync: surlignages — passage complet dû');
        return;
      }
      final books = _extractedBooks ?? const <KindleBookProgress>[];
      final libraryAsins = books
          .map((b) => b.asin)
          .whereType<String>()
          .where((a) => a.isNotEmpty)
          .toSet();
      final crawled = await _autoSyncService.highlightCrawledAsins();
      final only = <String>{
        ...await _progressDeltaAsins(),
        ...libraryAsins.difference(crawled),
      };
      _highlightFullCrawl = false;
      _highlightAsinsFilter = only.toList();
      debugPrint(
        'KindleAutoSync: surlignages — crawl incrémental de ${only.length} '
        'livre(s) (${libraryAsins.difference(crawled).length} jamais crawlés)',
      );
    } catch (e) {
      debugPrint('KindleAutoSync: plan de crawl KO ($e) → complet');
      _highlightAsinsFilter = null;
      _highlightFullCrawl = true;
    }
  }

  /// ASIN dont le % extrait dépasse le % stocké côté LexDay.
  Future<List<String>> _progressDeltaAsins() async {
    final books = _extractedBooks;
    if (books == null) return const [];
    final withPct = books
        .where((b) => b.asin != null && b.percentComplete != null)
        .toList();
    if (withPct.isEmpty) return const [];
    final stored = await BooksService()
        .getKindlePercentsByAsin(withPct.map((b) => b.asin!).toList());
    return [
      for (final b in withPct)
        if (stored[b.asin] != null && b.percentComplete! > stored[b.asin]!)
          b.asin!,
    ];
  }

  /// Crawl des surlignages : injecte le crawler asynchrone, le polle jusqu'à
  /// `done` (ou l'échéance du budget), puis collecte le résultat par tranches.
  /// Un résultat partiel est importé tel quel — la dédup fait le reste.
  Future<void> _extractHighlights() async {
    final deadline = DateTime.now().add(_highlightsTimeout);
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (_disposed || _finalizing) return;

      // Filtre du crawl incrémental (null = tous). Liste vide = rien à
      // recrawler : on ne lance même pas le crawler.
      final filter = _highlightAsinsFilter;
      if (filter != null && filter.isEmpty) {
        debugPrint('KindleAutoSync: surlignages — rien à recrawler');
        await _finalize(reason: 'ok');
        return;
      }
      await _controller.runJavaScriptReturningResult(
        KindleWebViewService.setNotebookCrawlFilterScript(filter),
      );
      await _controller.runJavaScriptReturningResult(
        KindleWebViewService.startNotebookCrawlScript,
      );

      var done = false;
      while (DateTime.now().isBefore(deadline)) {
        if (_disposed || _finalizing) return;
        await Future.delayed(const Duration(milliseconds: 1500));
        try {
          final status = await _controller.runJavaScriptReturningResult(
            KindleWebViewService.checkNotebookCrawlScript,
          );
          final s = status.toString();
          if (s.contains('"done":true')) {
            done = true;
            break;
          }
          // Le crawler n'existe pas dans la page (navigation intermédiaire,
          // script bloqué) : inutile d'attendre le budget entier.
          if (s.contains('"exists":false')) break;
        } catch (_) {
          break;
        }
      }

      final collected = <KindleHighlight>[];
      for (var start = 0; start < _maxHighlightsPerSync;
          start += _highlightsChunkSize) {
        if (_disposed || _finalizing) return;
        final chunk = await _controller.runJavaScriptReturningResult(
          KindleWebViewService.collectNotebookChunkScript(
            start,
            _highlightsChunkSize,
          ),
        );
        final parsed = _service.parseNotebookChunk(chunk.toString());
        collected.addAll(parsed);
        if (parsed.length < _highlightsChunkSize) break;
      }

      if (collected.isNotEmpty) _extractedHighlights = collected;
      debugPrint(
        'KindleAutoSync: ${collected.length} surlignages extraits '
        '(crawl ${done ? 'complet' : 'partiel'})',
      );
      // Registre du crawl incrémental : seulement si le crawl est allé au
      // bout, sinon on recrawlera ces livres la prochaine fois.
      if (done) {
        final crawledAsins = _highlightAsinsFilter ??
            (_extractedBooks ?? const <KindleBookProgress>[])
                .map((b) => b.asin)
                .whereType<String>()
                .toList();
        await _autoSyncService.markHighlightsCrawled(
          crawledAsins,
          full: _highlightFullCrawl,
        );
      }
    } catch (e) {
      debugPrint('KindleAutoSync: erreur extraction surlignages: $e');
    } finally {
      await _finalize(reason: 'ok');
    }
  }

  /// Phase 4 : ouvre le Cloud Reader des livres les plus récents et relève la
  /// position de lecture. Met à jour `percentComplete` dans `_extractedBooks`
  /// (consommé juste après par `importKindleBooks`). Les livres non ouverts
  /// gardent `null` : le 0 de l'API JSON n'est pas une information.
  Future<void> _extractReaderProgress() async {
    final books = _extractedBooks;
    if (books == null || books.isEmpty) return;
    final withAsin =
        books.where((b) => b.asin != null && b.asin!.isNotEmpty).toList();
    if (withAsin.isEmpty) {
      debugPrint('KindleAutoSync: progression — aucun ASIN (voie DOM ?), skip');
      return;
    }

    // Voie 1 : HTML du lecteur (pas de rendu). Nécessite une page
    // read.amazon.com sous les pieds pour le fetch same-origin : on se pose
    // sur l'endpoint JSON (quelques Ko) et on attend qu'il soit là.
    final found = <String, KindleReaderProgress>{};
    try {
      await _controller.loadRequest(Uri.parse(_kindleLibraryJsonUrl));
      final ready = await _waitForHost('read.amazon.com');
      if (ready && !_disposed) {
        // Les N plus récents côté Amazon + tous les livres « en cours » côté
        // LexDay (statut reading ou 1-99 % connu), dédoublonnés, plafonnés.
        final htmlAsins = withAsin
            .take(_maxHtmlProgressBooks)
            .map((b) => b.asin!)
            .toList();
        try {
          final known = withAsin.map((b) => b.asin!).toSet();
          for (final asin in await BooksService().getKindleAsinsInProgress()) {
            if (htmlAsins.length >= _maxHtmlProgressBooksTotal) break;
            // Seulement des livres encore présents dans la bibliothèque Amazon.
            if (known.contains(asin) && !htmlAsins.contains(asin)) {
              htmlAsins.add(asin);
            }
          }
        } catch (e) {
          debugPrint('KindleAutoSync: livres en cours LexDay KO: $e');
        }
        final sw = Stopwatch()..start();
        found.addAll(await _service.fetchReaderProgressViaHtml(
          _controller,
          htmlAsins,
          shouldAbort: () => _disposed,
        ));
        debugPrint(
          'KindleAutoSync: progression HTML — ${found.length}/${htmlAsins.length} '
          'livres en ${sw.elapsedMilliseconds} ms',
        );
        for (final b in withAsin) {
          final p = found[b.asin];
          if (p != null) {
            debugPrint('KindleAutoSync: progression « ${b.title} » = ${p.percent}%');
          }
        }
      }
    } catch (e) {
      debugPrint('KindleAutoSync: progression HTML KO: $e');
    }

    if (found.isNotEmpty || _disposed) {
      _applyReaderProgress(books, found);
      return;
    }

    // Voie 2 (repli) : rendu du Cloud Reader dans la WebView, N livres.
    debugPrint('KindleAutoSync: progression — repli sur le rendu du lecteur');
    final candidates = withAsin.take(_maxReaderProgressBooks).toList();
    for (final book in candidates) {
      if (_disposed) break;
      final asin = book.asin!;
      try {
        await _controller.loadRequest(
          Uri.parse('https://read.amazon.com/?asin=$asin'),
        );
        final deadline = DateTime.now().add(_readerProgressTimeout);
        String lastRaw = '';
        while (DateTime.now().isBefore(deadline)) {
          await Future.delayed(const Duration(seconds: 1));
          if (_disposed) break;
          final raw = await _controller.runJavaScriptReturningResult(
            KindleWebViewService.readKindleReaderProgressScript,
          );
          lastRaw = raw.toString();
          final progress =
              _service.parseReaderProgress(lastRaw, expectedAsin: asin);
          if (progress != null) {
            found[asin] = progress;
            debugPrint(
              'KindleAutoSync: progression « ${book.title} » = '
              '${progress.percent}% (Kindle p.${progress.kindlePage}/'
              '${progress.kindlePageCount})',
            );
            break;
          }
        }
        if (!found.containsKey(asin)) {
          debugPrint(
            'KindleAutoSync: progression « ${book.title} » non lue '
            '(pied de page absent avant l\'échéance) — dernier état: $lastRaw',
          );
          try {
            final diag = await _controller.runJavaScriptReturningResult(
              KindleWebViewService.readerDiagnosticScript,
            );
            debugPrint('KindleAutoSync: diagnostic lecteur: $diag');
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('KindleAutoSync: progression « ${book.title} » erreur: $e');
      }
    }

    _applyReaderProgress(books, found);
  }

  /// Vrai s'il existe au moins un livre dont la progression Kindle a AUGMENTÉ
  /// par rapport au pourcentage stocké côté LexDay — donc une session à dater.
  /// Une baseline (rien de stocké) ne compte pas : pas de session créée.
  Future<bool> _hasProgressDelta() async {
    final books = _extractedBooks;
    if (books == null) return false;
    final withPct = books
        .where((b) => b.asin != null && b.percentComplete != null)
        .toList();
    if (withPct.isEmpty) return false;
    try {
      final stored = await BooksService()
          .getKindlePercentsByAsin(withPct.map((b) => b.asin!).toList());
      return withPct.any((b) {
        final prev = stored[b.asin];
        return prev != null && b.percentComplete! > prev;
      });
    } catch (e) {
      debugPrint('KindleAutoSync: lecture des % stockés KO: $e');
      return true; // dans le doute, on va chercher le calendrier
    }
  }

  void _applyReaderProgress(
    List<KindleBookProgress> books,
    Map<String, KindleReaderProgress> found,
  ) {
    if (found.isEmpty) return;
    _extractedBooks = books
        .map((b) => found.containsKey(b.asin)
            ? b.copyWith(percentComplete: found[b.asin]!.percent)
            : b)
        .toList();
  }

  /// Attend (≤ 10 s) que la page courante soit servie par [host] et chargée.
  Future<bool> _waitForHost(String host) async {
    for (var i = 0; i < 20; i++) {
      if (_disposed) return false;
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final r = await _controller.runJavaScriptReturningResult(
          "JSON.stringify({h: location.host, s: document.readyState})",
        );
        final st = r.toString();
        if (st.contains(host) && st.contains('complete')) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Rend la main au parent, une seule fois quel que soit le chemin.
  void _complete(VoidCallback onCompleted) {
    if (_completedCalled) return;
    _completedCalled = true;
    onCompleted();
  }

  /// Phase 3-4 : import Supabase et persistance, hors WebView.
  ///
  /// Volontairement insensible à `_disposed` : le widget peut être démonté
  /// pendant l'import (Future non annulable), ce travail-là doit aller au bout.
  /// Les callbacks sont capturés localement pour ne pas toucher `widget` après
  /// dispose.
  Future<void> _finalize({required String reason}) async {
    if (_finalizing) return;
    _finalizing = true;
    _timeoutTimer?.cancel();

    final onCompleted = widget.onCompleted;
    final onSyncSuccess = widget.onSyncSuccess;

    _finalizeWatchdog = Timer(_finalizeTimeout, () {
      debugPrint('KindleAutoSync: finalisation trop longue, on rend la main');
      _complete(onCompleted);
    });

    // Progression via le lecteur : seulement sur un chemin sain (cookies
    // valides, widget monté). `_finalizing` est déjà posé, donc les
    // navigations de cette phase ne déclenchent plus rien dans
    // `_onPageFinished`. Borné par nature (N livres × budget), pas de chrono
    // externe ; le watchdog de finalisation reste la ceinture.
    if (reason == 'ok' && !_sessionExpired && !_disposed && !_progressDone) {
      try {
        await _extractReaderProgress();
      } catch (e) {
        debugPrint('KindleAutoSync: erreur phase progression: $e');
      }
      // Mini-sync : le sync complet a déjà lu le calendrier sur Insights ;
      // ici on ne charge la page que s'il y a un delta à dater.
      if (_progressOnly && _calendar == null && !_disposed && await _hasProgressDelta()) {
        try {
          await _controller.loadRequest(Uri.parse(_readingInsightsUrl));
          if (await _waitForHost('www.amazon.com')) {
            await _extractCalendar();
          }
        } catch (e) {
          debugPrint('KindleAutoSync: calendrier (mini-sync) KO: $e');
        }
      }
    }

    try {
      // Non-nullable : évite de dépendre de la promotion de type via un
      // booléen local, qui casserait au premier refactor.
      final books = _extractedBooks ?? const <KindleBookProgress>[];
      final streaks = _extractedStreaks;
      final hasBooks = books.isNotEmpty;

      // On importe TOUT ce qui a été extrait, même sur un chemin d'échec : la
      // liste vient forcément d'une page authentifiée, elle est donc valide,
      // et c'est elle qui porte la valeur du sync.
      var sessionsCreated = 0;
      if (hasBooks) {
        try {
          final booksService = BooksService();
          final imported = await booksService.importKindleBooks(
            books,
            calendar: _calendar,
          );
          sessionsCreated = booksService.kindleSessionsCreated;
          debugPrint(
            'KindleAutoSync: $imported nouveaux livres importés, '
            '$sessionsCreated session(s) Kindle créée(s)',
          );
        } catch (e) {
          debugPrint('KindleAutoSync: erreur import livres: $e');
        }
      }
      if (sessionsCreated > 0 && !_disposed) {
        widget.onKindleSessionsCreated?.call(sessionsCreated);
      }

      // Cookies Amazon valides (on vient de lire des pages authentifiées) :
      // copie pour la tâche d'arrière-plan, qui n'a pas de WebView.
      if (reason == 'ok' && !_sessionExpired) {
        await KindleCookieStore.refreshFromWebView();
        unawaited(KindleBackgroundSync.ensureScheduled());
      }

      if (_progressOnly) {
        // Rien d'autre à persister : pas de `kindle_last_sync` (le sync
        // complet garde son rythme), pas de SnackBar « synchronisé ».
        debugPrint(
          'KindleAutoSync: mini-sync progression terminé ($reason) — '
          '${books.length} livres, $sessionsCreated session(s)',
        );
        return;
      }

      // Marquer les livres terminés APRÈS l'import (markBooksAsFinished résout
      // les titres via la table `books`, qui vient d'être alimentée), mais sans
      // dépendre de lui : les livres peuvent déjà exister d'un sync précédent.
      final finishedTitles = streaks?.books ?? const <KindleBookProgress>[];
      if (finishedTitles.isNotEmpty) {
        try {
          final marked = await BooksService().markBooksAsFinished(finishedTitles);
          debugPrint('KindleAutoSync: $marked livres marqués terminés');
        } catch (e) {
          debugPrint('KindleAutoSync: erreur marquage terminés: $e');
        }
      }

      // Surlignages → Mes passages. APRÈS importKindleBooks : la résolution
      // titre → livre s'appuie sur la table `books` fraîchement alimentée.
      // Idempotent (dédup par source_key), best-effort comme le reste.
      final highlights = _extractedHighlights ?? const <KindleHighlight>[];
      if (highlights.isNotEmpty) {
        try {
          final imported =
              await BooksService().importKindleHighlights(highlights);
          debugPrint(
            'KindleAutoSync: $imported nouveaux surlignages importés '
            '(${highlights.length} extraits)',
          );
          if (imported > 0) {
            unawaited(AnalyticsService().track(
              AnalyticsEvent.kindleHighlightsSynced,
              properties: {
                'imported': imported,
                'extracted': highlights.length,
              },
            ));
          }
        } catch (e) {
          debugPrint('KindleAutoSync: erreur import surlignages: $e');
        }
      }

      // Un sync compte comme réussi dès qu'on a ramené quelque chose de réel.
      // Exiger les streaks pour poser `kindle_last_sync` ferait retenter un
      // import complet toutes les 6 h indéfiniment dès qu'Amazon ne sert pas la
      // page Insights (redirection régionale, interstitiel, JS en erreur) —
      // soit un martèlement pire que le bug d'origine.
      if (hasBooks || streaks != null) {
        final cached = await _service.loadFromCache();
        // Tout-ou-rien sur les streaks : on ne reprend le cache que si
        // l'extraction entière a échoué. Une fusion champ par champ
        // (`streaks?.x ?? cached?.x`) empêcherait une série de REDESCENDRE —
        // Amazon retire le bloc « days in a row » quand la série est cassée, on
        // ressortirait alors l'ancienne valeur à vie.
        final s = streaks ?? cached;
        final finalData = KindleReadingData(
          booksReadThisYear: s?.booksReadThisYear,
          currentStreak: s?.currentStreak,
          weeksStreak: s?.weeksStreak,
          daysStreak: s?.daysStreak,
          longestStreak: s?.longestStreak,
          totalDaysRead: s?.totalDaysRead,
          totalMinutesRead: s?.totalMinutesRead,
          books: hasBooks ? books : (cached?.books ?? const []),
        );

        if (_sessionExpired) {
          // Surtout PAS saveLocally ici : il poserait `kindle_last_sync` sur
          // une session morte (date de synchro mensongère + rendormissement
          // 24 h) et effacerait le throttle de la notification de reconnexion
          // que `onCookiesExpired` vient d'écrire.
          await _service.cacheBooksOnly(finalData.books);
        } else {
          await _service.saveLocally(finalData);
          unawaited(
            _autoSyncService.recordSuccess().catchError(
                  (Object e) =>
                      debugPrint('KindleAutoSync: recordSuccess failed: $e'),
                ),
          );
        }

        try {
          await _service.saveToSupabase(finalData);
        } catch (e) {
          debugPrint('KindleAutoSync: Supabase save failed: $e');
        }

        debugPrint(
          'KindleAutoSync: sync terminé ($reason) — '
          '${finalData.books.length} livres, streaks=${streaks != null}',
        );

        // Pas de SnackBar « synchronisé » juste après un « session expirée » :
        // les deux messages se contrediraient.
        if (!_disposed && !_sessionExpired) {
          onSyncSuccess?.call(finalData);
        }
      } else {
        debugPrint(
          'KindleAutoSync: rien à sauvegarder ($reason) — '
          'nouvelle tentative après le backoff',
        );
      }
    } catch (e) {
      debugPrint('KindleAutoSync: erreur finalisation: $e');
    } finally {
      _finalizeWatchdog?.cancel();
      _complete(onCompleted);
    }
  }

  @override
  Widget build(BuildContext context) {
    // WebView invisible pour l'utilisateur mais avec un VRAI viewport et
    // réellement composée (positionnée hors écran, pas Offstage).
    //
    // Test simulateur du 12/09/2026 : en `Offstage` + 1×1, la bibliothèque
    // JSON, Insights et le notebook passaient (pur fetch/DOM), mais le Cloud
    // Reader ne rendait jamais son pied de page « Page X of Y » — l'app
    // Ionic se dimensionne sur le viewport et ne s'initialise pas dans 1 px,
    // et un platform view non composé peut être traité comme non visible par
    // WebKit (rAF/timers throttlés). Un viewport iPhone hors écran règle les
    // deux. Le parent est un Stack (MainNavigation) : `Positioned` s'applique.
    return Positioned(
      left: -_hiddenViewportSize.width - 20,
      top: 0,
      width: _hiddenViewportSize.width,
      height: _hiddenViewportSize.height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

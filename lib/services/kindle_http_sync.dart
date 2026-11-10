// lib/services/kindle_http_sync.dart
//
// Sync de la progression Kindle en PUR HTTP, sans WebView — la brique du
// palier 2 (« rien à faire ») : exécutable dans l'isolate headless de
// workmanager, en arrière-plan, avec les cookies Amazon mis en cache par
// [KindleCookieStore] lors du dernier passage au premier plan.
//
// Reprend exactement les trois sources vérifiées en réel (12/09/2026) :
//   1. `read.amazon.com/kindle-library/search` (JSON) → ASIN, titres,
//      couvertures, ordre de récence (percentageRead = 0 partout, ignoré) ;
//   2. `read.amazon.com/?asin=X` (HTML rendu côté serveur) → JSON inline
//      `mostRecentPositionRead` / `srl` / `endReadingPosition` → % lu ;
//   3. `www.amazon.com/kindle/reading/insights` (HTML) → `"days_read":[…]`
//      pour dater la session au vrai jour de lecture.
// Les parseurs sont des fonctions pures (testables sans réseau).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'books_service.dart';
import 'kindle_auto_sync_service.dart';
import 'kindle_webview_service.dart';

class KindleHttpSyncResult {
  final int booksFetched;
  final int withProgress;
  final int sessionsCreated;
  final bool sessionExpired;
  final String? error;

  /// Livres dont on a réellement demandé la page lecteur.
  final int booksQueried;

  /// Amazon a répondu 200 pour des pages lecteur, mais AUCUNE ne contient les
  /// champs de position (`endReadingPosition`) : la mise en page a très
  /// probablement changé. À distinguer de « aucun livre ouvert récemment »,
  /// qui ressemblait exactement à ça avant.
  final bool layoutSuspect;

  /// Surlignages : livres entièrement crawlés, surlignages extraits, nouveaux
  /// surlignages réellement insérés.
  final int highlightBooks;
  final int highlightsExtracted;
  final int highlightsImported;

  const KindleHttpSyncResult({
    this.booksFetched = 0,
    this.withProgress = 0,
    this.sessionsCreated = 0,
    this.sessionExpired = false,
    this.error,
    this.booksQueried = 0,
    this.layoutSuspect = false,
    this.highlightBooks = 0,
    this.highlightsExtracted = 0,
    this.highlightsImported = 0,
  });

  bool get ok => error == null && !sessionExpired;
}

/// Une page de fragment notebook.
class KindleNotebookPage {
  final List<KindleHighlight> highlights;
  final String? nextToken;
  final String limitState;

  const KindleNotebookPage({
    required this.highlights,
    required this.nextToken,
    required this.limitState,
  });
}

/// Résultat d'un crawl de surlignages en HTTP.
class KindleHighlightCrawl {
  final List<KindleHighlight> highlights;

  /// ASIN parcourus jusqu'à la dernière page (seuls à marquer « crawlés »).
  final List<String> completeAsins;

  /// Amazon a demandé un login sur le notebook (pas une session expirée).
  final bool blocked;

  const KindleHighlightCrawl({
    required this.highlights,
    required this.completeAsins,
    required this.blocked,
  });
}

class KindleHttpSync {
  /// Même UA que la WebView cachée : Amazon sert la même variante de page.
  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  static const String libraryJsonUrl =
      'https://read.amazon.com/kindle-library/search'
      '?query=&libraryType=BOOKS&sortType=recency&querySize=50';
  static const String insightsUrl =
      'https://www.amazon.com/kindle/reading/insights';

  /// Budget iOS BGAppRefresh ≈ 30 s : on reste sobre.
  static const Duration requestTimeout = Duration(seconds: 8);
  static const int maxRecentBooks = 5;
  static const int maxBooksTotal = 8;

  // ── Surlignages en arrière-plan ──
  // Budget iOS ≈ 30 s pour TOUT le run (bibliothèque + lecteurs + insights +
  // surlignages) : on ne démarre plus de requête de surlignages après
  // [highlightsStopAfter], et pas du tout si le reste a déjà trop duré.
  static const Duration highlightsSkipIfElapsed = Duration(seconds: 16);
  static const Duration highlightsStopAfter = Duration(seconds: 20);
  static const Duration fragmentTimeout = Duration(seconds: 6);
  static const int maxHighlightBooks = 6;
  static const int maxHighlightPagesPerBook = 20;
  static const int maxHighlightsPerRun = 1000;

  final http.Client _client;
  final String cookieHeader;

  KindleHttpSync({required this.cookieHeader, http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Cookie': cookieHeader,
    'User-Agent': userAgent,
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
  };

  /// Session Amazon expirée si la réponse a fini sur une page de login.
  static bool isSignInResponse(http.Response r) {
    final url = r.request?.url.toString() ?? '';
    if (url.contains('/ap/signin') || url.contains('/ap/register')) return true;
    final loc = r.headers['location'] ?? '';
    if (r.statusCode >= 300 && r.statusCode < 400 && loc.contains('/ap/')) {
      return true;
    }
    return false;
  }

  Future<http.Response> _get(String url, {Map<String, String>? extra}) async {
    final res = await _client
        .get(Uri.parse(url), headers: {..._headers, ...?extra})
        .timeout(requestTimeout);
    _collectSetCookies(res);
    return res;
  }

  /// Ferme le client HTTP. À appeler quand le sync est terminé.
  void close() => _client.close();

  // ───────────────────── Rotation des cookies ─────────────────────
  //
  // Amazon fait tourner certains cookies de session (réponses `Set-Cookie`).
  // Sans les relire, la copie en cache vieillit et finit sur /ap/signin alors
  // que la session est valable. On ne met à jour QUE des cookies déjà présents
  // dans le cache (jamais d'ajout) : on prolonge, on n'invente rien.
  final Map<String, String> _rotatedCookies = {};

  void _collectSetCookies(http.Response r) {
    final raw = r.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    // `http` fusionne plusieurs Set-Cookie avec ", " ; les dates `Expires`
    // contiennent aussi une virgule, d'où le lookahead sur `nom=`.
    for (final part in raw.split(RegExp(r',(?=\s*[A-Za-z0-9_\-\.]+=)'))) {
      if (RegExp('max-age=0', caseSensitive: false).hasMatch(part)) continue;
      final first = part.split(';').first.trim();
      final eq = first.indexOf('=');
      if (eq <= 0) continue;
      final name = first.substring(0, eq).trim();
      final value = first.substring(eq + 1).trim();
      if (value.isEmpty || value == '""') continue; // suppression de cookie
      _rotatedCookies[name] = value;
    }
  }

  /// En-tête `Cookie` mis à jour avec les valeurs tournées pendant ce sync, ou
  /// `null` si rien n'a changé.
  String? get refreshedCookieHeader {
    if (_rotatedCookies.isEmpty) return null;
    var changed = false;
    final out = <String>[];
    for (final c in cookieHeader.split(';')) {
      final t = c.trim();
      if (t.isEmpty) continue;
      final eq = t.indexOf('=');
      if (eq <= 0) {
        out.add(t);
        continue;
      }
      final name = t.substring(0, eq);
      final fresh = _rotatedCookies[name];
      if (fresh != null && fresh != t.substring(eq + 1)) {
        out.add('$name=$fresh');
        changed = true;
      } else {
        out.add(t);
      }
    }
    return changed ? out.join('; ') : null;
  }

  /// La page lecteur a-t-elle la structure attendue ? (`endReadingPosition`
  /// est le champ dont dépend tout le calcul du %.)
  static bool readerLayoutLooksValid(String html) =>
      html.contains('endReadingPosition');

  // ───────────────────────── Parseurs purs ─────────────────────────

  /// Bibliothèque (page 1 seulement : 50 livres, ordre de récence).
  static List<KindleBookProgress> parseLibraryJson(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return [];
    final items = json['itemsList'] as List<dynamic>? ?? const [];
    final out = <KindleBookProgress>[];
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final title = (raw['title'] as String?)?.trim();
      if (title == null || title.isEmpty) continue;
      if (KindleWebViewService.isIgnoredBook(title)) continue;
      out.add(
        KindleBookProgress(
          title: title,
          author: _cleanAuthor(raw['authors']),
          percentComplete: null, // percentageRead = 0 partout : pas une info
          coverUrl: raw['productUrl'] as String?,
          asin: raw['asin'] as String?,
        ),
      );
    }
    return out;
  }

  static String? _cleanAuthor(dynamic a) {
    if (a == null) return null;
    var s = a is List ? a.whereType<String>().join(', ') : a.toString();
    s = s
        .replaceAll(RegExp(r':\s*'), ', ')
        .replaceAll(RegExp(r',\s*,'), ',')
        .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    return s.isEmpty ? null : s;
  }

  /// % lu depuis le HTML du lecteur. `null` si le livre n'a jamais été
  /// ouvert ou si les champs manquent (refonte Amazon).
  static int? parseReaderPercent(String html) {
    final t = html.replaceAll(r'\x22', '"');
    int? num(String key) {
      final m = RegExp('"$key":(-?\\d+)').firstMatch(t);
      return m == null ? null : int.tryParse(m.group(1)!);
    }

    final end = num('endReadingPosition');
    if (end == null || end <= 0) return null;
    final pos = num('mostRecentPositionRead');
    if (pos == null) return null;
    var srl = num('srl') ?? 0;
    if (srl < 0) srl = 0;
    final span = end - srl;
    if (span <= 0) return 0;
    return ((pos - srl) / span * 100).round().clamp(0, 100);
  }

  /// Jours lus (`"days_read":["2026-09-11", …]`) dans le HTML d'Insights.
  static List<DateTime> parseInsightsDaysRead(String html) {
    final k = html.indexOf('"days_read"');
    if (k < 0) return [];
    final a = html.indexOf('[', k);
    final b = html.indexOf(']', a);
    if (a < 0 || b < 0) return [];
    try {
      final arr = jsonDecode(html.substring(a, b + 1)) as List<dynamic>;
      final out = <DateTime>[];
      for (final d in arr) {
        if (d is! String) continue;
        final p = DateTime.tryParse(d);
        if (p != null) out.add(DateTime(p.year, p.month, p.day));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  // ───────────────── Surlignages (notebook) : port Dart du crawler JS ─────────────────
  //
  // Port fidèle de `KindleWebViewService.startNotebookCrawlScript` : mêmes
  // sélecteurs, mêmes clés de dédup (`source_key`), donc un surlignage vu par
  // l'un ou l'autre chemin n'est JAMAIS inséré deux fois.

  /// Hash identique à celui du JS (`h = ((h<<5)-h+c)|0`, puis `>>>0` en base 36).
  static String hashText(String s) {
    var h = 0;
    for (final u in s.codeUnits) {
      h = ((h << 5) - h + u) & 0xFFFFFFFF;
    }
    return h.toRadixString(36);
  }

  /// Parse un fragment `/notebook?asin=…` : surlignages + token de page suivante.
  /// [seen] est partagé entre les pages d'un crawl (dédup intra-run).
  static KindleNotebookPage parseNotebookFragment(
    String html, {
    required String asin,
    required String title,
    String? author,
    Set<String>? seen,
    int maxHighlights = 2000,
    int alreadyCollected = 0,
  }) {
    final doc = html_parser.parse(html);
    final seenKeys = seen ?? <String>{};
    final out = <KindleHighlight>[];

    for (final hl in doc.querySelectorAll('#highlight')) {
      if (alreadyCollected + out.length >= maxHighlights) break;
      final text = hl.text.trim();
      if (text.length < 2 || text.length > 5000) continue;

      // La ligne d'annotation porte l'id Amazon, la note et la location.
      dom.Element? row = hl.parent;
      for (dom.Element? e = hl.parent; e != null; e = e.parent) {
        if (e.classes.contains('a-row')) {
          row = e;
          break;
        }
      }

      String? note;
      int? location;
      int? page;
      var rowId = '';
      if (row != null) {
        rowId = (row.attributes['id'] ?? '').trim();
        final n = row.querySelector('#note')?.text.trim() ?? '';
        if (n.isNotEmpty && n.length < 5000) note = n;
        final locVal = row
            .querySelector('#kp-annotation-location')
            ?.attributes['value'];
        if (locVal != null) location = int.tryParse(locVal.trim());
        final header = row.querySelector('#annotationHighlightHeader')?.text;
        if (header != null) {
          // « Page: 42 » uniquement — jamais la location (≠ page).
          final pm = RegExp(
            r'page[^0-9]{0,3}([0-9]+)',
            caseSensitive: false,
          ).firstMatch(header);
          if (pm != null) page = int.tryParse(pm.group(1)!);
        }
      }

      final key = rowId.length >= 8
          ? 'kindle:$asin:$rowId'
          : 'kindle:$asin:${location ?? 'x'}:${hashText(text)}';
      if (!seenKeys.add(key)) continue;

      out.add(
        KindleHighlight(
          asin: asin,
          bookTitle: title,
          bookAuthor: author,
          text: text,
          note: note,
          page: page,
          sourceKey: key,
        ),
      );
    }

    final tokenVal = doc
        .querySelector('.kp-notebook-annotations-next-page-start')
        ?.attributes['value'];
    final limitVal = doc
        .querySelector('.kp-notebook-content-limit-state')
        ?.attributes['value'];
    return KindleNotebookPage(
      highlights: out,
      nextToken: (tokenVal == null || tokenVal.isEmpty) ? null : tokenVal,
      limitState: limitVal ?? '',
    );
  }

  /// Crawle les surlignages de [books] (séquentiel, borné en temps par [sw]).
  /// Un livre est « complet » s'il a été parcouru jusqu'à la dernière page.
  /// Une demande de login sur le notebook n'est PAS une session expirée
  /// (Amazon peut exiger une ré-authentification pour cette page seule) : on
  /// arrête simplement les surlignages.
  Future<KindleHighlightCrawl> crawlHighlights(
    List<KindleBookProgress> books,
    Stopwatch sw,
  ) async {
    final all = <KindleHighlight>[];
    final complete = <String>[];
    final seen = <String>{};
    var blocked = false;

    bookLoop:
    for (final book in books) {
      final asin = book.asin;
      if (asin == null || asin.isEmpty) continue;
      String? token;
      var limit = '';
      var finished = false;
      for (var page = 0; page < maxHighlightPagesPerBook; page++) {
        if (sw.elapsed > highlightsStopAfter ||
            all.length >= maxHighlightsPerRun) {
          break bookLoop;
        }
        final url =
            'https://read.amazon.com/notebook?asin='
            '${Uri.encodeQueryComponent(asin)}'
            '&contentLimitState=${Uri.encodeQueryComponent(limit)}'
            '${token != null ? '&token=${Uri.encodeQueryComponent(token)}' : ''}';
        http.Response r;
        try {
          r = await _client
              .get(
                Uri.parse(url),
                headers: {
                  ..._headers,
                  'X-Requested-With': 'XMLHttpRequest',
                  'Referer': 'https://read.amazon.com/notebook',
                },
              )
              .timeout(fragmentTimeout);
          _collectSetCookies(r);
        } catch (e) {
          debugPrint('KindleHttpSync: surlignages $asin KO: $e');
          break; // livre sauté, sera retenté (non marqué complet)
        }
        if (isSignInResponse(r)) {
          blocked = true;
          break bookLoop;
        }
        if (r.statusCode != 200) break;
        final p = parseNotebookFragment(
          r.body,
          asin: asin,
          title: book.title,
          author: book.author,
          seen: seen,
          maxHighlights: maxHighlightsPerRun,
          alreadyCollected: all.length,
        );
        all.addAll(p.highlights);
        if (p.nextToken == null) {
          // Plafond atteint en cours de page : le livre est tronqué.
          finished = all.length < maxHighlightsPerRun;
          break;
        }
        token = p.nextToken;
        limit = p.limitState;
      }
      if (finished) complete.add(asin);
    }
    return KindleHighlightCrawl(
      highlights: all,
      completeAsins: complete,
      blocked: blocked,
    );
  }

  // ───────────────────────── Pipeline ─────────────────────────

  /// Exécute un mini-sync progression complet (bibliothèque → % des livres
  /// récents/en cours → calendrier si delta → import + sessions).
  /// Suppose Supabase initialisé et une session utilisateur restaurée.
  Future<KindleHttpSyncResult> run() async {
    final sw = Stopwatch()..start();
    try {
      // 1. Bibliothèque (ASIN + récence)
      final libRes = await _get(
        libraryJsonUrl,
        extra: {'Accept': 'application/json'},
      );
      if (isSignInResponse(libRes)) {
        return const KindleHttpSyncResult(sessionExpired: true);
      }
      if (libRes.statusCode != 200) {
        return KindleHttpSyncResult(error: 'library HTTP ${libRes.statusCode}');
      }
      final books = parseLibraryJson(libRes.body);
      if (books.isEmpty) {
        return const KindleHttpSyncResult(error: 'library vide');
      }

      // 2. Livres à interroger : récents + en cours côté LexDay
      final booksService = BooksService();
      final byAsin = <String, KindleBookProgress>{
        for (final b in books)
          if (b.asin != null && b.asin!.isNotEmpty) b.asin!: b,
      };
      final asins = byAsin.keys.take(maxRecentBooks).toList();
      try {
        for (final asin in await booksService.getKindleAsinsInProgress()) {
          if (asins.length >= maxBooksTotal) break;
          if (byAsin.containsKey(asin) && !asins.contains(asin))
            asins.add(asin);
        }
      } catch (e) {
        debugPrint('KindleHttpSync: livres en cours KO: $e');
      }

      // 3. % lu par livre (HTML du lecteur)
      final progressed = <KindleBookProgress>[];
      var responded = 0; // pages lecteur reçues en 200
      var layoutOk = 0; // …dont la structure est celle attendue
      for (final asin in asins) {
        try {
          final r = await _get('https://read.amazon.com/?asin=$asin');
          if (isSignInResponse(r)) {
            return const KindleHttpSyncResult(sessionExpired: true);
          }
          if (r.statusCode != 200) continue;
          responded++;
          if (readerLayoutLooksValid(r.body)) layoutOk++;
          final pct = parseReaderPercent(r.body);
          if (pct == null) continue;
          progressed.add(byAsin[asin]!.copyWith(percentComplete: pct));
        } catch (e) {
          debugPrint('KindleHttpSync: $asin KO: $e');
        }
      }
      final layoutSuspect =
          progressed.isEmpty && responded > 0 && layoutOk == 0;

      // % déjà stockés côté LexDay, lus AVANT l'import : ils servent à détecter
      // le delta (calendrier) et à choisir les livres dont recrawler les
      // surlignages.
      Map<String, num?> stored = const {};
      if (progressed.isNotEmpty) {
        try {
          stored = await booksService.getKindlePercentsByAsin(
            progressed.map((b) => b.asin!).toList(),
          );
        } catch (e) {
          debugPrint('KindleHttpSync: % stockés KO: $e');
        }
      }

      var sessionsCreated = 0;
      if (progressed.isNotEmpty) {
        // 4. Calendrier Amazon, seulement s'il y a un delta à dater
        KindleInsightsCalendar? calendar;
        try {
          final hasDelta = progressed.any((b) {
            final prev = stored[b.asin];
            return prev != null && b.percentComplete! > prev;
          });
          final gate = KindleAutoSyncService();
          if (hasDelta || await gate.isCalendarSyncDue()) {
            final r = await _get(insightsUrl);
            if (r.statusCode == 200) {
              final days = parseInsightsDaysRead(r.body);
              if (days.isNotEmpty) {
                calendar = KindleInsightsCalendar(
                  daysRead: days,
                  finishedAt: const {},
                );
                // Jours lus → flamme, même sans delta de progression.
                await booksService.upsertKindleReadDays(days);
                await gate.recordCalendarSync();
              }
            }
          }
        } catch (e) {
          debugPrint('KindleHttpSync: calendrier KO: $e');
        }

        // 5. Import : % → user_books, delta → sessions. Seuls les livres avec
        // progression : pas d'import de nouveautés (ni Google Books) en
        // arrière-plan, le sync complet au premier plan s'en charge.
        await booksService.importKindleBooks(progressed, calendar: calendar);
        sessionsCreated = booksService.kindleSessionsCreated;
      }

      // 6. Surlignages (incrémental) : livres dont la progression a bougé, puis
      // livres jamais crawlés (par récence), plafonné. Jamais de passage
      // complet ici (le premier plan s'en charge, 1 fois / 7 jours) donc on ne
      // touche pas à `full`. Best-effort : n'impacte jamais le statut du sync.
      var hlBooks = 0;
      var hlExtracted = 0;
      var hlImported = 0;
      if (sw.elapsed < highlightsSkipIfElapsed) {
        try {
          final gate = KindleAutoSyncService();
          final crawled = await gate.highlightCrawledAsins();
          final delta = <String>[
            for (final b in progressed)
              if (stored[b.asin] != null &&
                  b.percentComplete! > stored[b.asin]!)
                b.asin!,
          ];
          final todo = <String>[
            ...delta,
            for (final a in byAsin.keys)
              if (!crawled.contains(a) && !delta.contains(a)) a,
          ].take(maxHighlightBooks).toList();
          if (todo.isNotEmpty) {
            final crawl = await crawlHighlights([
              for (final a in todo) byAsin[a]!,
            ], sw);
            hlExtracted = crawl.highlights.length;
            if (crawl.highlights.isNotEmpty) {
              hlImported = await booksService.importKindleHighlights(
                crawl.highlights,
              );
            }
            // Marqués APRÈS l'import, et seulement les livres parcourus en
            // entier : les autres seront retentés au prochain passage.
            if (crawl.completeAsins.isNotEmpty) {
              await gate.markHighlightsCrawled(
                crawl.completeAsins,
                full: false,
              );
            }
            hlBooks = crawl.completeAsins.length;
            debugPrint(
              'KindleHttpSync: surlignages — ${crawl.completeAsins.length}/'
              '${todo.length} livre(s), $hlExtracted extraits, $hlImported nouveaux'
              '${crawl.blocked ? ' (login demandé sur le notebook)' : ''}',
            );
          }
        } catch (e) {
          debugPrint('KindleHttpSync: surlignages KO: $e');
        }
      }

      return KindleHttpSyncResult(
        booksFetched: books.length,
        withProgress: progressed.length,
        sessionsCreated: sessionsCreated,
        booksQueried: asins.length,
        layoutSuspect: layoutSuspect,
        highlightBooks: hlBooks,
        highlightsExtracted: hlExtracted,
        highlightsImported: hlImported,
      );
    } catch (e) {
      return KindleHttpSyncResult(error: e.toString());
    }
  }
}

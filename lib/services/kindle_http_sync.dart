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

  const KindleHttpSyncResult({
    this.booksFetched = 0,
    this.withProgress = 0,
    this.sessionsCreated = 0,
    this.sessionExpired = false,
    this.error,
  });

  bool get ok => error == null && !sessionExpired;
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

  Future<http.Response> _get(String url, {Map<String, String>? extra}) {
    return _client
        .get(Uri.parse(url), headers: {..._headers, ...?extra})
        .timeout(requestTimeout);
  }

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
      out.add(KindleBookProgress(
        title: title,
        author: _cleanAuthor(raw['authors']),
        percentComplete: null, // percentageRead = 0 partout : pas une info
        coverUrl: raw['productUrl'] as String?,
        asin: raw['asin'] as String?,
      ));
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

  // ───────────────────────── Pipeline ─────────────────────────

  /// Exécute un mini-sync progression complet (bibliothèque → % des livres
  /// récents/en cours → calendrier si delta → import + sessions).
  /// Suppose Supabase initialisé et une session utilisateur restaurée.
  Future<KindleHttpSyncResult> run() async {
    try {
      // 1. Bibliothèque (ASIN + récence)
      final libRes = await _get(libraryJsonUrl, extra: {'Accept': 'application/json'});
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
          if (byAsin.containsKey(asin) && !asins.contains(asin)) asins.add(asin);
        }
      } catch (e) {
        debugPrint('KindleHttpSync: livres en cours KO: $e');
      }

      // 3. % lu par livre (HTML du lecteur)
      final progressed = <KindleBookProgress>[];
      for (final asin in asins) {
        try {
          final r = await _get('https://read.amazon.com/?asin=$asin');
          if (isSignInResponse(r)) {
            return const KindleHttpSyncResult(sessionExpired: true);
          }
          if (r.statusCode != 200) continue;
          final pct = parseReaderPercent(r.body);
          if (pct == null) continue;
          progressed.add(byAsin[asin]!.copyWith(percentComplete: pct));
        } catch (e) {
          debugPrint('KindleHttpSync: $asin KO: $e');
        }
      }
      if (progressed.isEmpty) {
        return KindleHttpSyncResult(booksFetched: books.length);
      }

      // 4. Calendrier Amazon, seulement s'il y a un delta à dater
      KindleInsightsCalendar? calendar;
      try {
        final stored = await booksService
            .getKindlePercentsByAsin(progressed.map((b) => b.asin!).toList());
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
              calendar = KindleInsightsCalendar(daysRead: days, finishedAt: const {});
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
      return KindleHttpSyncResult(
        booksFetched: books.length,
        withProgress: progressed.length,
        sessionsCreated: booksService.kindleSessionsCreated,
      );
    } catch (e) {
      return KindleHttpSyncResult(error: e.toString());
    }
  }
}

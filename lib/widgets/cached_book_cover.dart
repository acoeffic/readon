// lib/widgets/cached_book_cover.dart
// Widget réutilisable pour afficher les couvertures de livres avec cache

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Displays a book cover with a fallback chain.
///
/// URL chain (tried in order):
///   1. [imageUrl] — the stored cover URL (may be Google Books, OL, etc.)
///   2. Google Books thumbnail via [googleId] (deterministic URL pattern)
///   3. Google Books publisher-content via [googleId] (alternate endpoint)
///   4. iTunes/Apple Books lookup via [isbn]
///   5. Open Library cover via [isbn]
///   6. BnF (Bibliothèque nationale de France) cover via [isbn]
///   7. Title+author search (iTunes then Google Books API)
///   8. Placeholder widget
///
/// Google Books `content?id=` URLs are HEAD-checked to filter out the gray
/// "no preview" placeholder (valid HTTP 200 image but < 8 KB). Validated
/// results are cached statically so each URL is checked at most once per app
/// session. Publisher-content URLs (`/publisher/content/images/frontcover/`)
/// are NOT HEAD-checked — they return 404 cleanly when no cover exists.
///
/// Each remaining URL is loaded by [CachedNetworkImage]. On network error or
/// HTTP failure, the widget advances to the next URL.
class CachedBookCover extends StatefulWidget {
  final String? imageUrl;
  final String? isbn;
  final String? googleId;
  final String? title;
  final String? author;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Static cache: resolved URL list per book (shared across all instances).
  /// Key is "imageUrl|isbn|googleId", value is the validated URL list.
  static final Map<String, List<String>> _resolvedCache = {};

  /// Returns the first resolved cover URL for a given book, or null if not yet resolved.
  /// This allows other parts of the app (e.g. share cards) to use the same cover
  /// that CachedBookCover displays, instead of the raw database URL.
  static String? resolvedUrl({String? imageUrl, String? isbn, String? googleId}) {
    final key = '$imageUrl|$isbn|$googleId';
    final urls = CachedBookCover._resolvedCache[key];
    return (urls != null && urls.isNotEmpty) ? urls.first : null;
  }

  const CachedBookCover({
    super.key,
    required this.imageUrl,
    this.isbn,
    this.googleId,
    this.title,
    this.author,
    this.width = 50,
    this.height = 70,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedBookCover> createState() => _CachedBookCoverState();
}

class _CachedBookCoverState extends State<CachedBookCover> {
  int _urlIndex = 0;
  List<String> _urls = const [];
  bool _resolving = true;

  static const _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  };

  /// Static cache: Google Books URL → true (real cover) / false (placeholder).
  static final Map<String, bool> _gbHeadCache = {};

  /// Static cache: BnF ISBN → cover URL (null = no cover found).
  static final Map<String, String?> _bnfCache = {};

  /// BnF circuit breaker: skip all BnF calls after consecutive failures.
  static int _bnfConsecutiveFailures = 0;
  static DateTime? _bnfSkipUntil;

  /// Session cache: ISBN → iTunes cover URL (null = no cover found).
  /// Not static — clears on widget rebuild to avoid stale results.
  final Map<String, String?> _itunesCache = {};


  /// Google Books gray placeholder is ~1.3 KB at zoom=1 and ~9.1 KB at
  /// zoom=2/3. Real covers are almost always > 15 KB.
  static const int _minGbCoverBytes = 10000;

  /// Publisher-content placeholder PNG is 3,522 bytes.
  /// Lower threshold since this endpoint may serve smaller valid images.
  static const int _minPubCoverBytes = 4000;

  /// Open Library "image not available" placeholder can be up to ~4 KB
  /// at medium size. Real covers are almost always > 5 KB.
  static const int _minOlCoverBytes = 5000;

  @override
  void initState() {
    super.initState();
    _resolveChain();
  }

  @override
  void didUpdateWidget(CachedBookCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.isbn != widget.isbn ||
        oldWidget.googleId != widget.googleId) {
      _urlIndex = 0;
      _resolving = true;
      _resolveChain();
    }
  }

  String get _cacheKey =>
      '${widget.imageUrl}|${widget.isbn}|${widget.googleId}';

  Future<void> _resolveChain() async {
    // Return cached result if the same book was already resolved.
    final cached = CachedBookCover._resolvedCache[_cacheKey];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _urls = cached;
          _resolving = false;
        });
      }
      return;
    }

    final candidates = _buildCandidateUrls();
    final validated = <String>[];
    final cleanIsbn = _cleanIsbn(widget.isbn) ??
        _extractIsbnFromOlUrl(widget.imageUrl);
    final hasValidIsbn = _isValidIsbn(cleanIsbn);
    bool itunesInserted = false;

    for (final url in candidates) {
      if (_isGoogleBooksUrl(url)) {
        if (await _isRealGoogleBooksCover(url)) {
          validated.add(url);
        } else {
          // Try the publisher-content thumbnail API as a fallback.
          // HEAD-checked with a lower threshold (placeholder is ~3.5 KB).
          final volumeId = _extractGoogleBooksId(url);
          if (volumeId != null) {
            final pubUrl =
                'https://books.google.com/books/publisher/content'
                '/images/frontcover/$volumeId'
                '?fife=w400-h600&source=gbs_api';
            if (await _isRealGoogleBooksCover(
              pubUrl,
              minBytes: _minPubCoverBytes,
            )) {
              final resolved = await _resolveRedirects(pubUrl);
              validated.add(resolved);
            }
          }
        }
      } else {
        // Insert iTunes cover before the first non-Google-Books URL (i.e. OL).
        if (!itunesInserted && hasValidIsbn) {
          itunesInserted = true;
          final itunesUrl = await _fetchItunesCover(cleanIsbn!);
          if (itunesUrl != null) validated.add(itunesUrl);
        }
        // HEAD-check Open Library URLs to filter out "image not available" placeholders.
        if (url.contains('covers.openlibrary.org')) {
          if (await _isRealOpenLibraryCover(url)) {
            validated.add(url);
          }
        } else {
          validated.add(url);
        }
      }
    }

    // If all candidates were Google Books (no OL), still try iTunes by ISBN.
    if (!itunesInserted && hasValidIsbn) {
      final itunesUrl = await _fetchItunesCover(cleanIsbn!);
      if (itunesUrl != null) validated.add(itunesUrl);
    }

    // BnF — excellent for French-published books.
    if (hasValidIsbn) {
      final bnfUrl = await _fetchBnfCover(cleanIsbn!);
      if (bnfUrl != null) validated.add(bnfUrl);
    }

    // Google Books API search is DISABLED here to save quota.
    // But iTunes search by title+author is free (no Google quota) — use it
    // as a last resort when we have fewer than 2 validated URLs.
    if (validated.isEmpty && widget.title != null && widget.title!.isNotEmpty) {
      final itunesUrl = await _fetchItunesCoverByTitle(
        widget.title!,
        widget.author,
      );
      if (itunesUrl != null) validated.add(itunesUrl);
    }

    debugPrint(
      '📖 CachedBookCover [${widget.title}] '
      'isbn=${widget.isbn} googleId=${widget.googleId} '
      'resolved ${validated.length} URLs: $validated',
    );

    // Cache the result so other instances of the same book skip the chain.
    CachedBookCover._resolvedCache[_cacheKey] = validated;

    if (mounted) {
      setState(() {
        _urls = validated;
        _resolving = false;
      });
    }
  }

  static bool _isGoogleBooksUrl(String url) =>
      url.contains('books.google.com');

  /// Extract the volume `id` param from a Google Books URL.
  static String? _extractGoogleBooksId(String url) {
    final match = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    return match?.group(1);
  }

  /// True only for real ISBN-10 or ISBN-13 (digits only, correct length).
  static bool _isValidIsbn(String? isbn) {
    if (isbn == null) return false;
    final clean = isbn.replaceAll(RegExp(r'[\s-]'), '');
    // ISBN-10 can end with 'X' (check digit for 10), ISBN-13 is always digits.
    return RegExp(r'^\d{9}[\dXx]$|^\d{13}$').hasMatch(clean);
  }

  /// Check a Google Books URL; returns false if the response is the
  /// gray "no preview" placeholder (< [minBytes] bytes).
  ///
  /// Uses HEAD first; falls back to GET when content-length is missing
  /// to measure actual body size and avoid showing gray placeholders.
  static Future<bool> _isRealGoogleBooksCover(
    String url, {
    int minBytes = _minGbCoverBytes,
  }) async {
    final cached = _gbHeadCache[url];
    if (cached != null) return cached;

    try {
      final response = await http
          .head(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        _gbHeadCache[url] = false;
        return false;
      }
      final length =
          int.tryParse(response.headers['content-length'] ?? '') ?? 0;

      if (length >= minBytes) {
        // Size looks good from HEAD — but near the threshold, do a GET
        // to rule out grayscale PNG placeholders (which can be ~9 KB).
        if (length < minBytes * 2) {
          final getResp = await http
              .get(Uri.parse(url), headers: _browserHeaders)
              .timeout(const Duration(seconds: 4));
          if (getResp.statusCode == 200 && _isGrayscalePng(getResp.bodyBytes)) {
            _gbHeadCache[url] = false;
            return false;
          }
        }
        _gbHeadCache[url] = true;
        return true;
      }
      if (length > 0 && length < minBytes) {
        _gbHeadCache[url] = false;
        return false;
      }

      // content-length missing — do a GET to check actual body size
      // and detect grayscale PNG placeholders.
      final getResp = await http
          .get(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 4));
      if (getResp.statusCode != 200) {
        _gbHeadCache[url] = false;
        return false;
      }
      final bytes = getResp.bodyBytes;
      if (bytes.length < minBytes || _isGrayscalePng(bytes)) {
        _gbHeadCache[url] = false;
        return false;
      }
      _gbHeadCache[url] = true;
      return true;
    } catch (_) {
      _gbHeadCache[url] = false;
      return false;
    }
  }

  /// Static cache: Open Library URL → true (real cover) / false (placeholder).
  static final Map<String, bool> _olHeadCache = {};

  /// Check an Open Library URL; returns false if the response is the
  /// "image not available" placeholder (< [_minOlCoverBytes]) or a 404.
  ///
  /// Always does a GET to check actual body size AND detect the placeholder
  /// by looking for known small image dimensions in the response bytes.
  static Future<bool> _isRealOpenLibraryCover(String url) async {
    final cached = _olHeadCache[url];
    if (cached != null) return cached;

    try {
      // Try HEAD first to catch 404/302 quickly.
      final headResp = await http
          .head(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      if (headResp.statusCode == 404 || headResp.statusCode == 302) {
        _olHeadCache[url] = false;
        return false;
      }
      if (headResp.statusCode != 200) {
        _olHeadCache[url] = false;
        return false;
      }

      final length =
          int.tryParse(headResp.headers['content-length'] ?? '') ?? 0;
      if (length > 0 && length < _minOlCoverBytes) {
        // Server reported a small size → placeholder.
        _olHeadCache[url] = false;
        return false;
      }

      // Always do a GET to verify — the OL "image not available" PNG can be
      // larger than _minOlCoverBytes depending on encoding, so we also check
      // image dimensions. A real book cover is almost always > 150px wide.
      final getResp = await http
          .get(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 4));
      if (getResp.statusCode != 200) {
        _olHeadCache[url] = false;
        return false;
      }

      final bytes = getResp.bodyBytes;
      if (bytes.length < _minOlCoverBytes) {
        _olHeadCache[url] = false;
        return false;
      }

      // Check for PNG dimensions — if the image is very small (< 130px wide),
      // it's likely the "image not available" placeholder.
      final width = _extractImageWidth(bytes);
      if (width != null && width < 130) {
        _olHeadCache[url] = false;
        return false;
      }

      _olHeadCache[url] = true;
      return true;
    } catch (_) {
      _olHeadCache[url] = false;
      return false;
    }
  }

  /// Extract image width from PNG or JPEG header bytes.
  /// Returns null if the format is unrecognized.
  static int? _extractImageWidth(List<int> bytes) {
    if (bytes.length < 24) return null;

    // PNG: bytes 16-19 contain width as big-endian uint32
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    }

    // JPEG: scan for SOF0/SOF2 marker (0xFF 0xC0 or 0xFF 0xC2)
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      int i = 2;
      while (i < bytes.length - 9) {
        if (bytes[i] == 0xFF) {
          final marker = bytes[i + 1];
          if (marker == 0xC0 || marker == 0xC2) {
            // Width is at offset +7 (big-endian uint16)
            return (bytes[i + 7] << 8) | bytes[i + 8];
          }
          if (marker == 0xD9) break; // EOI
          if (marker == 0xDA) break; // SOS — no more markers
          // Skip to next marker
          final segLen = (bytes[i + 2] << 8) | bytes[i + 3];
          i += 2 + segLen;
        } else {
          i++;
        }
      }
    }

    // GIF: bytes 6-7 contain width as little-endian uint16
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return bytes[6] | (bytes[7] << 8);
    }

    return null;
  }

  /// Detect Google Books grayscale PNG placeholder.
  /// The "image not available" placeholder is a grayscale PNG (color type 0).
  /// Real book covers are RGB (color type 2) or RGBA (color type 6).
  /// PNG byte 25 is the color type in the IHDR chunk.
  static bool _isGrayscalePng(List<int> bytes) {
    if (bytes.length < 26) return false;
    // Check PNG magic bytes
    if (bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) {
      return false;
    }
    // PNG IHDR color type is at byte 25: 0 = grayscale, 2 = RGB, 6 = RGBA
    return bytes[25] == 0;
  }

  /// Look up a book cover via the BnF SRU API by ISBN.
  /// Queries the public catalogue, extracts the ARK identifier from the
  /// MARC-XML response, then returns the BnF cover URL (or null).
  static Future<String?> _fetchBnfCover(String isbn) async {
    if (_bnfCache.containsKey(isbn)) return _bnfCache[isbn];

    // Circuit breaker: skip BnF when their service is down.
    if (_bnfSkipUntil != null) {
      if (DateTime.now().isBefore(_bnfSkipUntil!)) return null;
      _bnfSkipUntil = null;
      _bnfConsecutiveFailures = 0;
    }

    try {
      final uri = Uri.parse(
        'https://catalogue.bnf.fr/api/SRU?version=1.2'
        '&operation=searchRetrieve'
        '&query=bib.isbn%20adj%20%22$isbn%22'
        '&maximumRecords=1',
      );
      final response = await http
          .get(uri, headers: _browserHeaders)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        _bnfCache[isbn] = null;
        return null;
      }

      // Extract the ARK identifier (e.g. ark:/12148/cb37615865s) from the XML.
      final arkMatch =
          RegExp(r'ark:/12148/cb\d+[a-z]?').firstMatch(response.body);
      if (arkMatch == null) {
        _bnfCache[isbn] = null;
        return null;
      }
      final ark = arkMatch.group(0)!;

      // Build the cover URL and HEAD-check it.
      final coverUrl =
          'https://catalogue.bnf.fr/couverture'
          '?appName=NE&idArk=$ark&couession=1';

      final head = await http
          .head(Uri.parse(coverUrl), headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      // BnF returns 200 with a real JPEG when a cover exists,
      // or a redirect / small placeholder otherwise.
      if (head.statusCode != 200) {
        // 500 = server error → count toward circuit breaker.
        if (head.statusCode >= 500) _bnfRecordFailure();
        _bnfCache[isbn] = null;
        return null;
      }
      final length =
          int.tryParse(head.headers['content-length'] ?? '') ?? 0;
      if (length > 0 && length < 2000) {
        // Tiny response — likely a placeholder or empty image.
        _bnfCache[isbn] = null;
        return null;
      }

      _bnfConsecutiveFailures = 0;
      _bnfCache[isbn] = coverUrl;
      return coverUrl;
    } catch (_) {
      _bnfRecordFailure();
      _bnfCache[isbn] = null;
      return null;
    }
  }

  /// Record a BnF failure; after 3 consecutive failures, skip for 10 minutes.
  static void _bnfRecordFailure() {
    _bnfConsecutiveFailures++;
    if (_bnfConsecutiveFailures >= 3) {
      _bnfSkipUntil = DateTime.now().add(const Duration(minutes: 10));
      debugPrint('BnF circuit breaker ouvert — pause de 10 min');
    }
  }

  // Google Books API search methods removed from display layer to save quota.
  // Cover enrichment is handled by BooksService.enrichMissingCovers().

  /// Follow redirects for a URL and return the final destination.
  /// Publisher-content URLs redirect to the actual image host; resolving
  /// up-front avoids redirect-related failures in CachedNetworkImage.
  static Future<String> _resolveRedirects(String url) async {
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false
        ..headers.addAll(_browserHeaders);
      final client = http.Client();
      try {
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 3));
        // Drain the body so the connection can be reused / closed.
        await response.stream.drain<void>();
        if (response.isRedirect ||
            (response.statusCode >= 300 && response.statusCode < 400)) {
          final location = response.headers['location'];
          if (location != null && location.isNotEmpty) {
            // Resolve relative redirects against the request URL.
            return Uri.parse(url).resolve(location).toString();
          }
        }
        // No redirect — return the original URL (it may serve directly).
        return url;
      } finally {
        client.close();
      }
    } catch (_) {
      return url;
    }
  }

  /// Look up a book cover via the iTunes Search API by ISBN.
  /// Tries FR store first, then US store as fallback.
  /// Returns a high-res artwork URL or null if not found.
  Future<String?> _fetchItunesCover(String isbn) async {
    final cached = _itunesCache[isbn];
    if (_itunesCache.containsKey(isbn)) return cached;

    for (final country in ['fr', 'us']) {
      try {
        final uri = Uri.parse(
          'https://itunes.apple.com/search'
          '?term=$isbn&media=ebook&limit=1&country=$country',
        );
        final response = await http
            .get(uri, headers: _browserHeaders)
            .timeout(const Duration(seconds: 3));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results == null || results.isEmpty) continue;
        final artwork = results.first['artworkUrl100'] as String?;
        if (artwork == null) continue;
        // Upgrade to high resolution.
        final url = artwork.replaceAll('100x100bb', '600x600bb');
        _itunesCache[isbn] = url;
        return url;
      } catch (_) {
        // Try next country.
      }
    }

    _itunesCache[isbn] = null;
    return null;
  }

  /// Search iTunes by title + author (no Google Books quota used).
  /// Uses Jaccard similarity to avoid returning covers for wrong books.
  static final Map<String, String?> _itunesTitleCache = {};

  Future<String?> _fetchItunesCoverByTitle(String title, String? author) async {
    final cacheKey = '$title|$author';
    if (_itunesTitleCache.containsKey(cacheKey)) return _itunesTitleCache[cacheKey];

    for (final country in ['fr', 'us']) {
      try {
        final query = Uri.encodeComponent('$title ${author ?? ''}');
        final uri = Uri.parse(
          'https://itunes.apple.com/search'
          '?term=$query&media=ebook&limit=5&country=$country',
        );
        final response = await http
            .get(uri, headers: _browserHeaders)
            .timeout(const Duration(seconds: 3));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results == null || results.isEmpty) continue;

        // Find the best match by title similarity
        final normTitle = _normalize(title);
        final normAuthor = author != null ? _normalize(author) : null;
        Map<String, dynamic>? best;
        double bestScore = 0;

        for (final r in results) {
          final trackName = r['trackName'] as String? ?? '';
          final artistName = r['artistName'] as String? ?? '';
          var score = _jaccard(normTitle, _normalize(trackName));
          if (normAuthor != null && normAuthor.isNotEmpty) {
            final authorScore = _jaccard(normAuthor, _normalize(artistName));
            if (authorScore > 0.5) {
              score += 0.15;
            } else if (authorScore < 0.15) {
              score -= 0.20;
            }
          }
          if (score > bestScore) {
            bestScore = score;
            best = r as Map<String, dynamic>;
          }
        }

        if (best != null && bestScore > 0.4) {
          final artwork = best['artworkUrl100'] as String?;
          if (artwork != null) {
            final url = artwork.replaceAll('100x100bb', '600x600bb');
            _itunesTitleCache[cacheKey] = url;
            return url;
          }
        }
      } catch (_) {}
    }

    _itunesTitleCache[cacheKey] = null;
    return null;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-–—:,;.!?\x27\x22«»()]+'), ' ')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e').replaceAll('ë', 'e')
        .replaceAll('à', 'a').replaceAll('â', 'a').replaceAll('ä', 'a')
        .replaceAll('ù', 'u').replaceAll('û', 'u').replaceAll('ü', 'u')
        .replaceAll('ô', 'o').replaceAll('ö', 'o')
        .replaceAll('î', 'i').replaceAll('ï', 'i')
        .replaceAll('ç', 'c').replaceAll('œ', 'oe').replaceAll('æ', 'ae')
        .replaceAll(RegExp(r'\(.*?\)'), '') // Remove parenthetical (French Edition) etc.
        .trim();
  }

  static double _jaccard(String a, String b) {
    final wordsA = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final wordsB = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return a == b ? 1.0 : 0.0;
    return wordsA.intersection(wordsB).length / wordsA.union(wordsB).length;
  }

  /// Extract ISBN from an Open Library cover URL.
  static String? _extractIsbnFromOlUrl(String? url) {
    if (url == null || !url.contains('covers.openlibrary.org/b/isbn/')) {
      return null;
    }
    final match = RegExp(r'/b/isbn/([0-9Xx-]+)-').firstMatch(url);
    if (match == null) return null;
    return _cleanIsbn(match.group(1));
  }

  /// Builds the ordered list of candidate cover URLs — purely synchronous.
  /// Google Books URLs in this list will be HEAD-validated by [_resolveChain].
  List<String> _buildCandidateUrls() {
    final urls = <String>[];
    final cleanIsbn = _cleanIsbn(widget.isbn);
    final primary = _normalizeUrl(widget.imageUrl);
    final primaryIsOl =
        primary != null && primary.contains('covers.openlibrary.org');
    final hasGoogleId =
        widget.googleId != null && widget.googleId!.isNotEmpty;

    // Google Books deterministic thumbnail URL (no API call needed).
    String? gbUrl;
    if (hasGoogleId) {
      gbUrl = 'https://books.google.com/books/content'
          '?id=${widget.googleId}'
          '&printsec=frontcover&img=1&zoom=3&source=gbs_api';
    }

    // --- Build the chain, preferring Google Books over Open Library. ---

    if (primary != null && !primaryIsOl) {
      // Primary is a Google Books URL or other trusted source → use it first.
      urls.add(primary);
      if (gbUrl != null && !primary.contains(widget.googleId!)) {
        urls.add(gbUrl);
      }
    } else if (gbUrl != null) {
      // Primary is OL (unreliable) or null → try Google Books first.
      urls.add(gbUrl);
      if (primary != null) urls.add(primary); // OL as fallback
    } else if (primary != null) {
      // No googleId, only OL URL → use it.
      urls.add(primary);
    }

    // Open Library via ISBN (different size / ISBN than primary OL URL).
    if (cleanIsbn != null && _isValidIsbn(cleanIsbn)) {
      final olUrl =
          'https://covers.openlibrary.org/b/isbn/$cleanIsbn-M.jpg?default=false';
      if (!urls.any((u) =>
          u.contains('covers.openlibrary.org') && u.contains(cleanIsbn))) {
        urls.add(olUrl);
      }
    }

    return urls;
  }

  /// Normalize a cover URL: http→https, strip ISBN hyphens in OL URLs,
  /// add ?default=false to OL, upgrade Google Books zoom.
  static String? _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Reject promotional Amazon images (app store badges, download banners)
    final lower = url.toLowerCase();
    if ((lower.contains('amazon') || lower.contains('ssl-images-amazon')) &&
        (lower.contains('badge') ||
            lower.contains('banner') ||
            lower.contains('button') ||
            lower.contains('app-store') ||
            lower.contains('google-play') ||
            lower.contains('windows-store') ||
            lower.contains('download') ||
            lower.contains('get-it-on') ||
            lower.contains('available-on') ||
            lower.contains('promo'))) {
      return null;
    }

    var u = url;

    if (u.startsWith('http:')) {
      u = u.replaceFirst('http:', 'https:');
    }

    if (u.contains('covers.openlibrary.org')) {
      final m = RegExp(r'/b/isbn/([0-9Xx-]+)-').firstMatch(u);
      if (m != null) {
        final raw = m.group(1)!;
        final clean = raw.replaceAll('-', '');
        if (clean.isEmpty) return null;
        if (raw != clean) u = u.replaceFirst(raw, clean);
      }
      if (!u.contains('default=false')) {
        u += u.contains('?') ? '&default=false' : '?default=false';
      }
    }

    if (u.contains('books.google.com') && u.contains('zoom=1')) {
      u = u.replaceFirst('zoom=1', 'zoom=3');
    }

    return u;
  }

  /// Strip hyphens/spaces, validate ISBN characters. Returns null if invalid.
  static String? _cleanIsbn(String? isbn) {
    if (isbn == null || isbn.isEmpty) return null;
    final cleaned = isbn.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty || !RegExp(r'^[0-9Xx]+$').hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fallback = widget.errorWidget ??
        widget.placeholder ??
        _GeneratedBookCover(
          title: widget.title,
          author: widget.author,
          width: widget.width,
          height: widget.height,
        );

    // Still HEAD-checking Google Books URLs → show shimmer.
    if (_resolving) {
      return _wrapBorderRadius(
        widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: colors.shimmerBase,
            ),
      );
    }

    // No valid URLs → show placeholder immediately.
    if (_urls.isEmpty || _urlIndex >= _urls.length) {
      return _wrapBorderRadius(fallback);
    }

    final dpr =
        ui.PlatformDispatcher.instance.displays.first.devicePixelRatio;

    final image = CachedNetworkImage(
      imageUrl: _urls[_urlIndex],
      width: widget.width,
      height: widget.height,
      memCacheWidth: (widget.width * dpr).toInt(),
      memCacheHeight: (widget.height * dpr).toInt(),
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: colors.shimmerBase,
          ),
      errorWidget: (context, url, error) {
        // Advance to the next URL in the chain.
        if (_urlIndex + 1 < _urls.length) {
          debugPrint(
            '📖 CachedBookCover [${widget.title}] '
            'URL #$_urlIndex failed ($error), trying #${_urlIndex + 1}: ${_urls[_urlIndex + 1]}',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _urlIndex++);
          });
          return widget.placeholder ??
              Container(
                width: widget.width,
                height: widget.height,
                color: colors.shimmerBase,
              );
        }
        return fallback;
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );

    return _wrapBorderRadius(image);
  }

  Widget _wrapBorderRadius(Widget child) {
    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }
    return child;
  }
}

/// A generated book cover placeholder showing the title and author on a
/// coloured background. The background colour is deterministic based on the
/// title so the same book always gets the same colour.
class _GeneratedBookCover extends StatelessWidget {
  final String? title;
  final String? author;
  final double width;
  final double height;

  const _GeneratedBookCover({
    required this.title,
    required this.author,
    required this.width,
    required this.height,
  });

  /// A curated palette of muted, book-like colours.
  static const _palette = [
    Color(0xFF6B988D), // sage green
    Color(0xFF8B7355), // warm brown
    Color(0xFF7A6F8E), // muted purple
    Color(0xFF8A6B5E), // terracotta
    Color(0xFF5E7A8A), // steel blue
    Color(0xFF8B8B6B), // olive
    Color(0xFF6B7A8B), // slate
    Color(0xFF9B7A6B), // dusty rose
  ];

  @override
  Widget build(BuildContext context) {
    final hash = (title ?? '').hashCode.abs();
    final bgColor = _palette[hash % _palette.length];
    final titleFontSize = (width * 0.14).clamp(8.0, 18.0);
    final authorFontSize = (width * 0.10).clamp(6.0, 12.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.12,
        vertical: height * 0.10,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (title != null && title!.isNotEmpty)
            Text(
              title!,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          if (author != null && author!.isNotEmpty) ...[
            SizedBox(height: height * 0.06),
            Text(
              author!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: authorFontSize,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

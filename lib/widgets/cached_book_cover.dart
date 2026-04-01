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
///   6. Title+author search (iTunes then Google Books API)
///   7. Placeholder widget
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

  /// Session cache: ISBN → iTunes cover URL (null = no cover found).
  /// Not static — clears on widget rebuild to avoid stale results.
  final Map<String, String?> _itunesCache = {};

  /// Session cache: title|author → cover URL from search (null = not found).
  /// Not static — clears on widget rebuild to avoid stale results.
  final Map<String, String?> _titleSearchCache = {};

  /// Google Books gray placeholder is typically 2–5 KB.
  /// Real covers are almost always > 15 KB.
  static const int _minGbCoverBytes = 8000;

  /// Publisher-content placeholder PNG is 3,522 bytes.
  /// Lower threshold since this endpoint may serve smaller valid images.
  static const int _minPubCoverBytes = 5000;

  /// Open Library "image not available" placeholder is ~800 bytes.
  /// Real covers are > 2 KB even at small sizes.
  static const int _minOlCoverBytes = 1500;

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

  Future<void> _resolveChain() async {
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

    // Last resort: search by title + author (or ISBN if valid).
    if (validated.isEmpty) {
      final fallbackUrl = await _fetchCoverByTitleAuthor(
        widget.title,
        widget.author,
        widget.isbn,
      );
      if (fallbackUrl != null) validated.add(fallbackUrl);
    }

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
    return RegExp(r'^\d{10}$|^\d{13}$').hasMatch(clean);
  }

  /// HEAD-check a Google Books URL; returns false if the response is the
  /// gray "no preview" placeholder (< [minBytes] bytes).
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
      // A content-length of 0 means the server didn't report it — accept it
      // and let CachedNetworkImage handle errors at render time.
      final valid = length == 0 || length >= minBytes;
      _gbHeadCache[url] = valid;
      return valid;
    } catch (_) {
      _gbHeadCache[url] = false;
      return false;
    }
  }

  /// Static cache: Open Library URL → true (real cover) / false (placeholder).
  static final Map<String, bool> _olHeadCache = {};

  /// HEAD-check an Open Library URL; returns false if the response is the
  /// "image not available" placeholder (< [_minOlCoverBytes]) or a 404.
  static Future<bool> _isRealOpenLibraryCover(String url) async {
    final cached = _olHeadCache[url];
    if (cached != null) return cached;

    try {
      final response = await http
          .head(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 404) {
        _olHeadCache[url] = false;
        return false;
      }
      if (response.statusCode != 200) {
        _olHeadCache[url] = false;
        return false;
      }
      final length =
          int.tryParse(response.headers['content-length'] ?? '') ?? 0;
      final valid = length == 0 || length >= _minOlCoverBytes;
      _olHeadCache[url] = valid;
      return valid;
    } catch (_) {
      _olHeadCache[url] = false;
      return false;
    }
  }

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
  /// Returns a high-res artwork URL or null if not found.
  Future<String?> _fetchItunesCover(String isbn) async {
    final cached = _itunesCache[isbn];
    if (_itunesCache.containsKey(isbn)) return cached;

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=$isbn&media=ebook&limit=1&country=fr',
      );
      final response = await http
          .get(uri, headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        _itunesCache[isbn] = null;
        return null;
      }
      final data = jsonDecode(response.body);
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        _itunesCache[isbn] = null;
        return null;
      }
      final artwork = results.first['artworkUrl100'] as String?;
      if (artwork == null) {
        _itunesCache[isbn] = null;
        return null;
      }
      // Upgrade to high resolution.
      final url = artwork.replaceAll('100x100bb', '600x600bb');
      _itunesCache[isbn] = url;
      return url;
    } catch (_) {
      _itunesCache[isbn] = null;
      return null;
    }
  }

  /// Last-resort: search for a cover by title and author.
  ///
  /// If [isbn] is valid, only tries ISBN-based iTunes lookup (precise).
  /// Title+author search (iTunes then Google Books API) only fires when
  /// ISBN is null or invalid to avoid false matches.
  Future<String?> _fetchCoverByTitleAuthor(
    String? title,
    String? author,
    String? isbn,
  ) async {
    if (title == null || title.isEmpty) return null;
    final cacheKey = '$title|$author|$isbn';
    if (_titleSearchCache.containsKey(cacheKey)) {
      return _titleSearchCache[cacheKey];
    }

    final cleanIsbn = _cleanIsbn(isbn);

    // If we have a valid ISBN, try ISBN-based iTunes lookup only.
    // Title search is too imprecise when we know the ISBN — if the ISBN
    // lookup already failed upstream, there's nothing more to do.
    if (_isValidIsbn(cleanIsbn)) {
      final isbnResult = await _fetchItunesCover(cleanIsbn!);
      _titleSearchCache[cacheKey] = isbnResult;
      return isbnResult;
    }

    // No valid ISBN — fall back to title+author search.

    // Try iTunes
    try {
      final query = Uri.encodeComponent('$title ${author ?? ''}');
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=$query&media=ebook&limit=1&country=fr',
      );
      final response = await http
          .get(uri, headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final artwork = results.first['artworkUrl100'] as String?;
          if (artwork != null) {
            final url = artwork.replaceAll('100x100bb', '600x600bb');
            _titleSearchCache[cacheKey] = url;
            return url;
          }
        }
      }
    } catch (_) {}

    // Try Google Books API search
    try {
      final query = Uri.encodeComponent(
        'intitle:$title${author != null ? '+inauthor:$author' : ''}',
      );
      final uri = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes'
        '?q=$query&fields=items/volumeInfo/imageLinks&maxResults=1',
      );
      final response = await http
          .get(uri, headers: _browserHeaders)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final links = items.first['volumeInfo']?['imageLinks']
              as Map<String, dynamic>?;
          if (links != null) {
            final url = (links['large'] ??
                    links['medium'] ??
                    links['small'] ??
                    links['thumbnail']) as String?;
            if (url != null) {
              final finalUrl = url.replaceFirst('http://', 'https://');
              _titleSearchCache[cacheKey] = finalUrl;
              return finalUrl;
            }
          }
        }
      }
    } catch (_) {}

    _titleSearchCache[cacheKey] = null;
    return null;
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

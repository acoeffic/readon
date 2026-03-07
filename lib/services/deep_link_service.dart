import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../pages/books/user_books_page.dart';
import 'books_service.dart';
import 'notion_service.dart';
import 'monthly_notification_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Reuses the navigator key already defined in MonthlyNotificationService.
  static GlobalKey<NavigatorState> get navigatorKey =>
      MonthlyNotificationService.navigatorKey;

  /// Call once after Supabase is initialised and the navigator is mounted.
  void init() {
    if (kIsWeb) return;

    // Cold-start link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    // Foreground links
    _sub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void dispose() {
    _sub?.cancel();
  }

  // ── Routing ──────────────────────────────────────────────────────────

  void _handleUri(Uri uri) {
    if (uri.scheme != 'lexday') return;

    // Notion OAuth callback — delegate to existing handler
    if (uri.host == 'notion' && uri.path.startsWith('/callback')) {
      NotionService().handleDeepLink(uri);
      return;
    }

    // Book deep link: lexday://book/{bookId}?from={userId}
    if (uri.host == 'book') {
      final bookIdStr = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (bookIdStr == null) return;

      final bookId = int.tryParse(bookIdStr);
      if (bookId == null) return;

      final sharedByUserId = uri.queryParameters['from'];
      _navigateToBook(bookId, sharedByUserId: sharedByUserId);
    }
  }

  Future<void> _navigateToBook(
    int bookId, {
    String? sharedByUserId,
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    try {
      final book = await BooksService().getBookById(bookId);
      nav.push(
        MaterialPageRoute(
          builder: (_) => BookDetailPage(
            book: book,
            sharedByUserId: sharedByUserId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('DeepLinkService: book $bookId not found — $e');
    }
  }
}

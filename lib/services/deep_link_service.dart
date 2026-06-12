import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../pages/auth/new_password_page.dart';
import '../pages/books/user_books_page.dart';
import '../pages/groups/groups_page.dart';
import '../pages/reading/start_reading_session_page_unified.dart';
import 'books_service.dart';
import 'notion_service.dart';
import 'monthly_notification_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  StreamSubscription<AuthState>? _authSub;
  bool _routingToReset = false;

  static GlobalKey<NavigatorState> get navigatorKey =>
      MonthlyNotificationService.navigatorKey;

  void init() {
    if (kIsWeb) return;

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    _sub = _appLinks.uriLinkStream.listen(_handleUri);

    // Flux `recovery` arrivant via le code PKCE (?code=) : le SDK émet
    // `passwordRecovery` après getSessionFromUrl. On route alors vers l'écran
    // de nouveau mot de passe. (Le cas token_hash est géré dans
    // _handleAuthCallback, qui émet `signedIn`, pas `passwordRecovery`.)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _goToNewPassword();
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
  }

  void _goToNewPassword() {
    if (_routingToReset) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _routingToReset = true;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NewPasswordPage()),
      (route) => false,
    ).then((_) => _routingToReset = false);
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != 'lexday') return;

    // Supabase auth callback (email confirmation, password reset, magic link)
    // L'URL arrive sous la forme :
    //   lexday://auth/callback?code=xxx                     (flow PKCE)
    //   lexday://auth/callback#access_token=...&type=signup (flow implicit)
    if (uri.host == 'auth' && uri.path.startsWith('/callback')) {
      _handleAuthCallback(uri);
      return;
    }

    // Notion OAuth callback
    if (uri.host == 'notion' && uri.path.startsWith('/callback')) {
      NotionService().handleDeepLink(uri);
      return;
    }

    // lexday://start-session (from iOS widget)
    if (uri.host == 'start-session') {
      _navigateToCurrentBook();
      return;
    }

    // lexday://book/{bookId}?from={userId}
    if (uri.host == 'book') {
      final bookIdStr = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (bookIdStr == null) return;

      final bookId = int.tryParse(bookIdStr);
      if (bookId == null) return;

      final sharedByUserId = uri.queryParameters['from'];
      _navigateToBook(bookId, sharedByUserId: sharedByUserId);
      return;
    }

    // lexday://groups
    if (uri.host == 'groups') {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(builder: (_) => const GroupsPage()),
      );
      return;
    }
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    try {
      // Lien email de confirmation / reset : la page web /confirm nous relaie
      // un `token_hash` (flux verifyOTP). Le code_verifier PKCE vit dans CETTE
      // app (c'est elle qui a fait le signUp), donc c'est ici qu'on valide le
      // token. verifyOTP crée la session et marque l'email confirmé.
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];
      if (tokenHash != null && tokenHash.isNotEmpty) {
        await Supabase.instance.client.auth.verifyOTP(
          type: _otpTypeFromString(type),
          tokenHash: tokenHash,
        );
        // Reset de mot de passe : la session de récupération est posée, on
        // amène l'utilisateur à l'écran « nouveau mot de passe ». (verifyOTP
        // émet `signedIn`, donc on route explicitement ici.)
        if (type == 'recovery') {
          _goToNewPassword();
        }
      } else {
        // Flux code PKCE (?code=) ou implicit (#access_token=...) : le SDK
        // parse l'URL, crée la session et la persiste.
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
      // Pour signup : l'AuthState `signedIn` est émis automatiquement →
      // ConfirmEmailPage redirige vers AuthGate.
    } catch (e) {
      debugPrint('DeepLinkService: auth callback failed — $e');
    }
  }

  OtpType _otpTypeFromString(String? type) {
    switch (type) {
      case 'recovery':
        return OtpType.recovery;
      case 'email':
        return OtpType.email;
      case 'email_change':
        return OtpType.emailChange;
      case 'magiclink':
        return OtpType.magiclink;
      case 'invite':
        return OtpType.invite;
      case 'signup':
      default:
        return OtpType.signup;
    }
  }

  Future<void> _navigateToCurrentBook() async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    try {
      final currentBookData = await BooksService().getCurrentReadingBook();
      if (currentBookData == null) return;

      final book = currentBookData['book'] as Book;
      nav.push(
        MaterialPageRoute(
          builder: (_) => StartReadingSessionPageUnified(book: book),
        ),
      );
    } catch (e) {
      debugPrint('DeepLinkService: cannot navigate to current book — $e');
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
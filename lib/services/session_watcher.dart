// lib/services/session_watcher.dart
//
// Filet de sécurité (05/10/2026) : quand gotrue supprime la session SANS que
// l'utilisateur se soit déconnecté (refresh token refusé par le serveur —
// cf. l'incident de rotation du token par l'isolate Kindle dans
// `kindle_background_sync.dart`), l'app restait sur ses écrans avec un header
// en cache (« Bonsoir Adrien », avatar…), mais `currentUser == null` : chaque
// action gated affichait le mur « Crée un compte gratuit » à un utilisateur
// connecté et premium, et le lancement suivant tombait sur l'écran de
// connexion sans explication.
//
// Ici, dès que `signedOut` arrive sans déconnexion explicite, on renvoie
// proprement à l'AuthGate (→ LoginPage) avec un message clair.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../pages/auth/auth_gate.dart';
import 'monthly_notification_service.dart';

class SessionWatcher {
  SessionWatcher._();

  static StreamSubscription<AuthState>? _sub;
  static bool _explicitSignOut = false;

  /// À appeler une fois au démarrage, après `Supabase.initialize`. Idempotent.
  static void start() {
    if (_sub != null) return;
    try {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event != AuthChangeEvent.signedOut) return;
        if (_explicitSignOut) {
          // Déconnexion volontaire : la page appelante gère sa navigation.
          _explicitSignOut = false;
          return;
        }
        debugPrint('SessionWatcher: session perdue sans déconnexion → login');
        redirectToLogin(sessionExpired: true);
      });
    } catch (e) {
      debugPrint('SessionWatcher.start ignoré: $e');
    }
  }

  /// À appeler AVANT `auth.signOut()` quand c'est l'utilisateur qui se
  /// déconnecte (réglages, suppression de compte) : le `signedOut` qui suit
  /// est attendu et ne doit pas déclencher le message « session expirée ».
  static void expectSignOut() => _explicitSignOut = true;

  /// Renvoie à l'écran de connexion (via AuthGate) en vidant la pile, avec
  /// un message si la session a expiré.
  static void redirectToLogin({required bool sessionExpired}) {
    final nav = MonthlyNotificationService.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
    if (!sessionExpired) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = MonthlyNotificationService.navigatorKey.currentContext;
      if (ctx == null) return;
      final l = AppLocalizations.of(ctx);
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(
          content: Text(l.sessionExpiredReconnect),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }
}

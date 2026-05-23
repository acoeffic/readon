// lib/services/analytics_service.dart
//
// Wrapper centralisé autour du SDK PostHog. Toutes les pages/services
// passent par ce service pour logger des events — jamais d'appel direct
// à `Posthog()` ailleurs dans le code.
//
// Cycle de vie :
//   1. `init()` : appelé au démarrage (splash) après chargement de Env.
//   2. `identify(userId, properties)` : appelé après login dans AuthGate.
//   3. `track(event, properties)` : à chaque action utilisateur loggée.
//   4. `reset()` : appelé au logout pour ne pas mélanger les sessions
//      d'utilisateurs différents sur le même device.
//
// Si `POSTHOG_API_KEY` est vide (env de dev sans clé), tous les appels
// sont no-op silencieux — pas d'erreurs en console.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env.dart';

/// Noms d'events centralisés. Évite les typos qui fragmenteraient les
/// funnels PostHog ("session_started" vs "Session Started" vs "sessionStarted").
/// Convention : snake_case, verbe au passé, scope préfixé.
abstract final class AnalyticsEvent {
  // ── Auth ──
  static const signupCompleted = 'signup_completed';
  static const loginSucceeded = 'login_succeeded';
  static const logout = 'logout';

  // ── Onboarding ──
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingStepSkipped = 'onboarding_step_skipped';
  static const onboardingCompleted = 'onboarding_completed';

  // ── Lecture ──
  static const sessionStarted = 'reading_session_started';
  static const sessionEnded = 'reading_session_ended';
  static const sessionPaused = 'reading_session_paused';
  static const sessionResumed = 'reading_session_resumed';
  static const sessionAbandoned = 'reading_session_abandoned';
  static const sessionRecovered = 'reading_session_recovered';

  // ── Livres ──
  static const bookAdded = 'book_added';
  static const bookFinished = 'book_finished';
  static const bookHidden = 'book_hidden';
  static const bookRemoved = 'book_removed';

  // ── Social ──
  static const friendRequestSent = 'friend_request_sent';
  static const friendRequestAccepted = 'friend_request_accepted';
  static const commentPosted = 'comment_posted';
  static const reactionAdded = 'reaction_added';
  static const profileShared = 'profile_shared';

  // ── Engagement ──
  static const wrappedOpened = 'wrapped_opened';
  static const wrappedShared = 'wrapped_shared';
  static const badgeUnlocked = 'badge_unlocked';
  static const badgeShared = 'badge_shared';
  static const streakBroken = 'streak_broken';

  // ── Notifications ──
  static const pushPermissionRequested = 'push_permission_requested';
  static const pushPermissionGranted = 'push_permission_granted';
  static const pushPermissionDenied = 'push_permission_denied';
  static const pushOpened = 'push_opened';

  // ── Monétisation ──
  static const paywallShown = 'paywall_shown';
  static const paywallDismissed = 'paywall_dismissed';
  static const subscriptionStarted = 'subscription_started';
  static const subscriptionCancelled = 'subscription_cancelled';
  static const amazonLinkClicked = 'amazon_link_clicked';
}

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;

  bool _initialized = false;
  bool get _enabled => _initialized && Env.posthogApiKey.isNotEmpty;

  /// À appeler une fois au démarrage de l'app, après chargement de l'env.
  Future<void> init() async {
    if (_initialized) return;
    if (Env.posthogApiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('AnalyticsService: POSTHOG_API_KEY vide — tracking désactivé');
      }
      return;
    }

    try {
      final config = PostHogConfig(Env.posthogApiKey)
        ..host = Env.posthogHost
        ..captureApplicationLifecycleEvents = true
        ..debug = kDebugMode
        ..sendFeatureFlagEvents = true
        // Par défaut PostHog v5 = `identifiedOnly` qui drop les events des
        // utilisateurs anonymes. On veut tracker tout le funnel y compris
        // pre-login (splash, écran de connexion, signup).
        ..personProfiles = PostHogPersonProfiles.always;

      await Posthog().setup(config);
      _initialized = true;
      debugPrint(
          'AnalyticsService: PostHog initialisé (host=${Env.posthogHost})');

      // Event de smoke test en debug pour confirmer la liaison réseau.
      if (kDebugMode) {
        unawaited(Posthog().capture(eventName: 'analytics_initialized'));
      }
    } catch (e, st) {
      debugPrint('AnalyticsService: init failed — $e\n$st');
    }
  }

  /// Lier les events à un utilisateur identifié (post-login).
  /// `properties` peut contenir email, displayName, plan, locale, etc.
  Future<void> identify({
    required String userId,
    Map<String, Object>? properties,
  }) async {
    if (!_enabled) return;
    try {
      await Posthog().identify(
        userId: userId,
        userProperties: properties,
      );
    } catch (e) {
      debugPrint('AnalyticsService.identify error: $e');
    }
  }

  /// Logguer un event. Voir [AnalyticsEvent] pour les noms standards.
  Future<void> track(
    String event, {
    Map<String, Object>? properties,
  }) async {
    if (!_enabled) return;
    try {
      await Posthog().capture(
        eventName: event,
        properties: properties,
      );
    } catch (e) {
      debugPrint('AnalyticsService.track error ($event): $e');
    }
  }

  /// Logguer une vue d'écran. Préférable d'utiliser le NavigatorObserver
  /// quand c'est possible (cf. [PosthogObserver]).
  Future<void> screen(
    String name, {
    Map<String, Object>? properties,
  }) async {
    if (!_enabled) return;
    try {
      await Posthog().screen(
        screenName: name,
        properties: properties,
      );
    } catch (e) {
      debugPrint('AnalyticsService.screen error ($name): $e');
    }
  }

  /// Mettre à jour les propriétés de l'utilisateur courant sans relog.
  /// Utile pour streak, count de livres, plan premium, etc.
  Future<void> setUserProperties(Map<String, Object> properties) async {
    if (!_enabled) return;
    try {
      await Posthog().setPersonProperties(userPropertiesToSet: properties);
    } catch (e) {
      debugPrint('AnalyticsService.setUserProperties error: $e');
    }
  }

  /// Couper le tracking pour un user qui retire son consentement.
  Future<void> optOut() async {
    if (!_enabled) return;
    try {
      await Posthog().disable();
    } catch (e) {
      debugPrint('AnalyticsService.optOut error: $e');
    }
  }

  Future<void> optIn() async {
    if (!_enabled) return;
    try {
      await Posthog().enable();
    } catch (e) {
      debugPrint('AnalyticsService.optIn error: $e');
    }
  }

  /// À appeler au logout pour réinitialiser le distinct_id PostHog —
  /// sinon les events anonymes du prochain user seront attribués à
  /// l'utilisateur précédent sur le même device.
  Future<void> reset() async {
    if (!_enabled) return;
    try {
      await Posthog().reset();
    } catch (e) {
      debugPrint('AnalyticsService.reset error: $e');
    }
  }

  /// Évaluer un feature flag côté PostHog (pour A/B test).
  Future<bool> isFeatureEnabled(String key) async {
    if (!_enabled) return false;
    try {
      return await Posthog().isFeatureEnabled(key);
    } catch (e) {
      debugPrint('AnalyticsService.isFeatureEnabled error ($key): $e');
      return false;
    }
  }
}

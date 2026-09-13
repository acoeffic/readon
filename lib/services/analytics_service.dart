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
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Noms d'events centralisés. Évite les typos qui fragmenteraient les
/// funnels PostHog ("session_started" vs "Session Started" vs "sessionStarted").
/// Convention : snake_case, verbe au passé, scope préfixé.
abstract final class AnalyticsEvent {
  // ── Auth ──
  static const signupCompleted = 'signup_completed';
  static const loginSucceeded = 'login_succeeded';
  static const logout = 'logout';

  /// « Continuer sans compte » depuis l'écran de connexion. Sans cet event, la
  /// population invitée est totalement invisible (aucune ligne en base).
  static const guestModeEntered = 'guest_mode_entered';

  /// Sortie du mode invité (l'utilisateur part créer un compte ou se
  /// connecter). Le couple entré/sorti donne le taux de conversion global.
  static const guestModeExited = 'guest_mode_exited';

  // ── Murs « compte requis » ──
  //
  // Le trio ci-dessous répond à la question qui vaut le plus cher : *quelle
  // action donne envie à un visiteur de créer un compte ?* Chaque event porte
  // un `source` (fab_scan, send_comment, tab_muse…). Le rapport
  // converted/shown par source désigne le meilleur hameçon de conversion.

  static const guestWallShown = 'guest_wall_shown';
  static const guestWallConverted = 'guest_wall_converted';
  static const guestWallDismissed = 'guest_wall_dismissed';

  // ── Onboarding ──
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingStepSkipped = 'onboarding_step_skipped';
  static const onboardingCompleted = 'onboarding_completed';
  /// Pré-prompt « On te rappelle demain ? » présenté à ceux qui sortent de
  /// l'onboarding sans lancer de session. Propriété `answer` : yes / no.
  static const onboardingReminderPrompt = 'onboarding_reminder_prompt';

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

  // ── Passages (capture hors session) ──
  //
  // Le cœur du pari « carnet de lecture » : capturer un passage doit valoir
  // quelque chose *sans* démarrer de session. Le ratio started/saved dit si
  // le tunnel photo → surlignage → sauvegarde tient la route.
  static const passageCaptureStarted = 'passage_capture_started';
  static const passageSaved = 'passage_saved';
  static const passageCaptureAbandoned = 'passage_capture_abandoned';
  static const passagesWallOpened = 'passages_wall_opened';
  static const passagesBookOpened = 'passages_book_opened';

  /// Surlignages Kindle importés par le sync auto (Readwise-like).
  /// `imported` = nouvelles lignes, `extracted` = total ramené par le crawl :
  /// le ratio dit si le lecteur surligne encore ou si on re-crawle du stock.
  static const kindleHighlightsSynced = 'kindle_highlights_synced';

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

  // ── Mode sans distraction (automatisations Raccourcis iOS) ──
  //
  // Entonnoir : suggestion post-session affichée → guide ouvert (avec
  // `source` : settings | post_session_suggestion) → app Raccourcis ouverte.
  // On ne peut pas savoir si l'automatisation est réellement créée (iOS ne
  // le dit pas) — le dernier event mesurable est l'ouverture de Raccourcis.
  static const focusSuggestionShown = 'focus_suggestion_shown';
  static const focusSuggestionDismissed = 'focus_suggestion_dismissed';
  static const focusGuideOpened = 'focus_guide_opened';
  static const focusGuideShortcutsOpened = 'focus_guide_shortcuts_opened';

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
  bool _authListenerAttached = false;
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

  /// Branche l'écoute des changements d'état d'authentification pour émettre
  /// [AnalyticsEvent.signupCompleted] / [AnalyticsEvent.loginSucceeded] depuis
  /// un seul endroit, quel que soit le chemin emprunté (email, Apple, Google).
  ///
  /// À appeler une fois au démarrage, après [init] et après
  /// `Supabase.initialize`. Idempotent.
  ///
  /// Distinction signup / login : `AuthChangeEvent.signedIn` ne dit pas si le
  /// compte vient d'être créé. On compare donc la date de création de
  /// l'utilisateur à l'instant courant — un compte de moins de deux minutes au
  /// moment du premier `signedIn` est une inscription.
  void attachAuthListener() {
    if (_authListenerAttached) return;
    _authListenerAttached = true;

    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        // `initialSession` (restauration au lancement) et `tokenRefreshed` ne
        // sont pas des connexions : les compter fausserait le funnel.
        if (state.event != AuthChangeEvent.signedIn) return;

        final user = state.session?.user;
        if (user == null) return;

        final createdAt = DateTime.tryParse(user.createdAt);
        final isFreshAccount = createdAt != null &&
            DateTime.now().toUtc().difference(createdAt.toUtc()) <
                const Duration(minutes: 2);

        final provider =
            (user.appMetadata['provider'] as String?) ?? 'email';

        unawaited(track(
          isFreshAccount
              ? AnalyticsEvent.signupCompleted
              : AnalyticsEvent.loginSucceeded,
          properties: {'provider': provider},
        ));
      });
    } catch (e) {
      debugPrint('AnalyticsService.attachAuthListener error: $e');
      _authListenerAttached = false;
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

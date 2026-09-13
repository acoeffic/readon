import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/wrapped/monthly/monthly_wrapped_screen.dart';
import 'analytics_service.dart';
import 'monthly_notification_service.dart';
import 'notification_permission.dart';
import 'wrapped_banner_service.dart';

/// Handles FCM token capture, storage in Supabase, token refresh,
/// and notification tap routing.
///
/// ⚠️ Découpage important (audit entonnoir du 15/08/2026) :
///
///   * [initialize] ne demande **jamais** la permission système. Elle câble le
///     routage des notifications et, si la permission est *déjà* accordée,
///     enregistre le token FCM. On l'appelle au login (AuthGate).
///   * [promptPermissionAndRegister] déclenche la popup système. Elle doit être
///     appelée à un moment où l'utilisateur a compris la valeur de l'app —
///     concrètement après sa première session de lecture terminée, pas au
///     premier lancement (le refus y était quasi systématique, et le canal de
///     relance J1 perdu avec).
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Routage des notifications câblé (listeners, cold start).
  bool _listenersReady = false;

  /// Token FCM récupéré et enregistré en base pour la session courante.
  bool _tokenRegistered = false;

  StreamSubscription<String>? _tokenRefreshSub;

  /// Pending FCM message from a cold-start tap. Consumed by MainNavigation.
  static RemoteMessage? pendingInitialMessage;

  /// Câble le routage des notifications et enregistre le token **si la
  /// permission est déjà accordée**. Ne présente aucune popup système.
  /// À appeler après l'authentification.
  Future<void> initialize() async {
    if (kIsWeb) return;

    await _setupListeners();

    // Permission déjà accordée (utilisateur existant, ou nouvelle install
    // après [promptPermissionAndRegister]) → on peut récupérer le token.
    if (await hasPermission()) {
      await _registerToken();
    }
  }

  /// Statut courant de la permission notifications. Délègue au helper partagé
  /// avec `MonthlyNotificationService` (une seule autorisation système pour
  /// les deux plugins) — voir `notification_permission.dart`.
  Future<AuthorizationStatus> permissionStatus() =>
      notificationPermissionStatus();

  /// `true` si l'utilisateur a accordé (ou provisoirement accordé) la
  /// permission notifications.
  Future<bool> hasPermission() => hasNotificationPermission();

  /// `true` si la popup système n'a encore jamais été présentée — donc si on
  /// a encore une (seule) cartouche à tirer.
  Future<bool> canStillAskPermission() => canStillAskNotificationPermission();

  /// Présente la popup système de permission puis, si elle est accordée,
  /// enregistre le token FCM.
  ///
  /// Retourne `true` si la permission est accordée à l'issue de l'appel.
  /// Ne fait rien (et retourne le statut courant) si la popup a déjà été
  /// présentée par le passé : iOS ne la réaffiche pas.
  Future<bool> promptPermissionAndRegister() async {
    if (kIsWeb) return false;

    await _setupListeners();

    unawaited(AnalyticsService().track(
      AnalyticsEvent.pushPermissionRequested,
    ));

    // Marqué avant l'appel : la popup est réputée consommée dès qu'on la
    // déclenche. Si le process est tué pendant que l'utilisateur regarde le
    // dialogue système, on ne le relancera pas au démarrage suivant.
    await markNotificationPromptShown();

    NotificationSettings settings;
    try {
      settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('PushNotificationService.requestPermission error: $e');
      return false;
    }

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    unawaited(AnalyticsService().track(
      granted
          ? AnalyticsEvent.pushPermissionGranted
          : AnalyticsEvent.pushPermissionDenied,
      properties: {'status': settings.authorizationStatus.name},
    ));

    if (!granted) {
      debugPrint(
          'Push permission not granted: ${settings.authorizationStatus.name}');
      return false;
    }

    await _registerToken();

    // Les notifications locales (Wrapped mensuel, rappels de lecture) ont été
    // ignorées à chaque tentative de planification tant que la permission
    // manquait. Maintenant qu'elle est accordée, on rattrape immédiatement au
    // lieu d'attendre le prochain lancement.
    try {
      await MonthlyNotificationService().scheduleNextMonthlyNotification();
    } catch (e) {
      debugPrint('Replanification post-permission ignorée: $e');
    }

    return true;
  }

  // ── Interne ────────────────────────────────────────────────────────────

  /// Récupère le token FCM et l'enregistre en base. Suppose la permission
  /// accordée. Idempotent sur la durée de vie de la session.
  Future<void> _registerToken() async {
    if (_tokenRegistered) return;
    _tokenRegistered = true;

    // Sur iOS, le token APNs doit être disponible avant le token FCM.
    if (Platform.isIOS) {
      String? apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) {
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
        }
      }
      if (apnsToken == null) {
        debugPrint(
            'FCM: APNs token indisponible après retries, on s\'en remet à onTokenRefresh');
      }
    }

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      } else {
        debugPrint('FCM token error: getToken() returned null (simulator?)');
        // Laisse une chance à un nouvel essai plus tard dans la session.
        _tokenRegistered = false;
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
      _tokenRegistered = false;
    }

    // Écoute du refresh de token (annule le listener précédent si besoin).
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);
  }

  /// Câble la présentation en premier plan, le routage des taps et la
  /// récupération du message de cold start. Idempotent.
  Future<void> _setupListeners() async {
    if (_listenersReady) return;
    _listenersReady = true;

    // Présentation des notifications app au premier plan (iOS).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Tap sur une notification (background → foreground).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Cold start : l'app était tuée, l'utilisateur a tapé une notification.
    // On stocke le message pour consommation par MainNavigation une fois le
    // navigateur prêt.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      pendingInitialMessage = initialMessage;
      // Pré-enregistre tout de suite l'état de bannière à partir du payload
      // — il y a une race condition possible avec _consumePendingNotification
      // (postFrameCallback). Si la course est perdue, la bannière dans le feed
      // prend le relais.
      final data = initialMessage.data;
      if (data['type'] == 'monthly_wrapped') {
        final month = int.tryParse(data['month'] ?? '');
        final year = int.tryParse(data['year'] ?? '');
        if (month != null && year != null) {
          await WrappedBannerService().setPending(month: month, year: year);
        }
      }
    }
  }

  /// Save or update the FCM token in the user's profile.
  Future<void> _saveToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('FCM token error: no authenticated user');
        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .upsert({'id': userId, 'fcm_token': token});

      debugPrint('FCM token saved');
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  /// Route the user to the correct screen based on the notification payload.
  static void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'monthly_wrapped':
        final month = int.tryParse(data['month'] ?? '');
        final year = int.tryParse(data['year'] ?? '');
        if (month == null || year == null) return;

        // Re-schedule local notification for next month
        MonthlyNotificationService().scheduleNextMonthlyNotification();

        // Toujours stocker l'état pour la bannière du feed (24 h) — ainsi
        // l'utilisateur peut ré-ouvrir le wrapped depuis le feed même si
        // la navigation directe échoue (navigatorKey pas encore prêt,
        // splash en cours, etc.).
        WrappedBannerService().setPending(month: month, year: year);

        // Tentative de navigation immédiate. Si le navigateur n'est pas
        // encore prêt (ex: app en cold start, splash visible), la bannière
        // dans le feed prendra le relais.
        _pushWrappedScreen(month: month, year: year);
      // Other notification types (comment, like, friend_request, etc.)
      // are handled by in-app navigation and don't need explicit routing here.
    }
  }

  /// Pousse l'écran Wrapped via le navigatorKey global. Réessaie après un
  /// court délai si l'état du navigateur n'est pas encore prêt (cold start).
  static void _pushWrappedScreen({
    required int month,
    required int year,
    int retriesLeft = 5,
  }) {
    final navState = MonthlyNotificationService.navigatorKey.currentState;
    if (navState == null) {
      if (retriesLeft <= 0) return;
      Future.delayed(const Duration(milliseconds: 400), () {
        _pushWrappedScreen(
          month: month,
          year: year,
          retriesLeft: retriesLeft - 1,
        );
      });
      return;
    }
    navState.push(
      MaterialPageRoute(
        builder: (_) => MonthlyWrappedScreen(month: month, year: year),
      ),
    );
  }

  /// Clear the FCM token from the profile (call on sign out).
  Future<void> clearToken() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);

      await _messaging.deleteToken();
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      _tokenRegistered = false;

      debugPrint('FCM token cleared');
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }
}

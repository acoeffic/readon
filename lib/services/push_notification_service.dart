import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/wrapped/monthly/monthly_wrapped_screen.dart';
import 'monthly_notification_service.dart';

/// Handles FCM token capture, storage in Supabase, token refresh,
/// and notification tap routing.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Pending FCM message from a cold-start tap. Consumed by MainNavigation.
  static RemoteMessage? pendingInitialMessage;

  /// Initialize push notifications: request permission, get token, listen for refresh.
  /// Call this after the user is authenticated.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;
    _initialized = true;

    // 1. Request permission (required on iOS, Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('FCM token error: permission denied');
      _initialized = false;
      return;
    }

    // 2. Get APNs token first on iOS (required before FCM token)
    if (Platform.isIOS) {
      String? apnsToken = await _messaging.getAPNSToken();
      // APNs token may not be available immediately on iOS — retry a few times
      if (apnsToken == null) {
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
        }
      }
      if (apnsToken == null) {
        print('FCM token error: APNs token not available after retries, will rely on onTokenRefresh');
      }
    }

    // 3. Get FCM token and save it
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      } else {
        print('FCM token error: getToken() returned null (simulator?)');
      }
    } catch (e) {
      print('FCM token error: $e');
    }

    // 4. Listen for token refresh (cancel previous listener if any)
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(newToken);
    });

    // 5. Configure foreground notification presentation (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. Handle notification taps (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // 7. Handle cold start (app was terminated, user tapped notification)
    // Store the message for consumption by MainNavigation once the navigator is ready.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      pendingInitialMessage = initialMessage;
    }
  }

  /// Save or update the FCM token in the user's profile.
  Future<void> _saveToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('FCM token error: no authenticated user');
        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .upsert({'id': userId, 'fcm_token': token});

      print('FCM token saved: $token');
    } catch (e) {
      print('FCM token error: $e');
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

        MonthlyNotificationService.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => MonthlyWrappedScreen(month: month, year: year),
          ),
        );
      // Other notification types (comment, like, friend_request, etc.)
      // are handled by in-app navigation and don't need explicit routing here.
    }
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
      _initialized = false;

      print('FCM token cleared');
    } catch (e) {
      print('FCM token error: $e');
    }
  }
}

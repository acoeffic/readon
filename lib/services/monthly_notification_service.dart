import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../features/wrapped/monthly/monthly_wrapped_screen.dart';

class MonthlyNotificationService {
  static final MonthlyNotificationService _instance =
      MonthlyNotificationService._internal();
  factory MonthlyNotificationService() => _instance;
  MonthlyNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Global navigator key — must be assigned to MaterialApp.navigatorKey.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const int _notificationId = 1001;
  static const String _channelId = 'monthly_wrapped';
  static const String _channelName = 'Résumé mensuel';
  static const String _channelDescription =
      'Notification mensuelle pour consulter ton résumé de lecture';

  bool _initialized = false;

  /// Initialize the plugin. Call once from main.dart.
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize timezone database
    tzdata.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // 2. Platform-specific settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 3. Initialize with tap callback
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;

    // 4. Handle cold start (app launched from notification tap)
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails!.notificationResponse != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _onNotificationTapped(launchDetails.notificationResponse!);
      });
    }

    // 5. Schedule the next notification
    await scheduleNextMonthlyNotification();
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.requestNotificationsPermission() ?? false;
      }
    }
    return true;
  }

  /// Schedule a notification for 9:00 AM on the 1st of next month.
  Future<void> scheduleNextMonthlyNotification() async {
    await _plugin.cancel(_notificationId);
    await requestPermission();

    final now = tz.TZDateTime.now(tz.local);
    final nextFirst = _nextFirstOfMonth(now);

    // Previous month relative to the notification date
    final prevMonth = nextFirst.month == 1 ? 12 : nextFirst.month - 1;
    final prevYear =
        nextFirst.month == 1 ? nextFirst.year - 1 : nextFirst.year;
    final payload = '$prevMonth:$prevYear';

    const monthNames = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      _notificationId,
      'Ton résumé de ${monthNames[prevMonth]} est prêt !',
      'Découvre tes stats de lecture du mois dernier',
      nextFirst,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint(
      'MonthlyNotification scheduled for $nextFirst (payload: $payload)',
    );
  }

  /// Next 1st-of-month at 09:00 local time.
  tz.TZDateTime _nextFirstOfMonth(tz.TZDateTime now) {
    var year = now.year;
    var month = now.month;

    final thisMonthFirst = tz.TZDateTime(tz.local, year, month, 1, 9);
    if (now.isAfter(thisMonthFirst)) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    return tz.TZDateTime(tz.local, year, month, 1, 9);
  }

  /// Called when user taps the notification.
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.contains(':')) return;

    final parts = payload.split(':');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MonthlyWrappedScreen(month: month, year: year),
      ),
    );
  }
}

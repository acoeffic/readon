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

  static const String _challengeChannelId = 'challenge_start';
  static const String _challengeChannelName = 'Début de défi';
  static const String _challengeChannelDescription =
      'Notification quand un défi de club commence';

  // Reading reminders — IDs 3000–3006 (one per day of week, Mon=0 → Sun=6)
  static const int _readingReminderBaseId = 3000;
  static const String _readingReminderChannelId = 'reading_reminder';
  static const String _readingReminderChannelName = 'Rappels de lecture';
  static const String _readingReminderChannelDescription =
      'Rappels quotidiens pour lire';

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

  /// Schedule a start notification for a challenge (at 9:00 AM on [startsAt]).
  /// Does nothing if [startsAt] is today or in the past.
  Future<void> scheduleChallengeStart({
    required String challengeId,
    required String notifTitle,
    required String notifBody,
    required DateTime startsAt,
  }) async {
    final startDate = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final todayDate = DateTime.now();
    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    if (!startDate.isAfter(today)) return;

    final scheduledTime = tz.TZDateTime(
      tz.local,
      startsAt.year,
      startsAt.month,
      startsAt.day,
      9,
    );

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _challengeChannelId,
        _challengeChannelName,
        channelDescription: _challengeChannelDescription,
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
      _challengeNotifId(challengeId),
      notifTitle,
      notifBody,
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('Challenge start notification scheduled: "$notifTitle" at $scheduledTime');
  }

  /// Cancel a previously scheduled challenge start notification.
  Future<void> cancelChallengeStart(String challengeId) async {
    await _plugin.cancel(_challengeNotifId(challengeId));
  }

  int _challengeNotifId(String challengeId) =>
      challengeId.hashCode.abs() % 8000 + 2000;

  // ── Reading reminders ──

  /// Schedule weekly recurring local notifications for reading reminders.
  ///
  /// [time] — the user's chosen reminder time (e.g. 20:00).
  /// [isoDays] — list of ISO day numbers (1=Mon … 7=Sun) on which to remind.
  Future<void> scheduleReadingReminders({
    required TimeOfDay time,
    required List<int> isoDays,
  }) async {
    // Cancel all existing reading reminders first
    await cancelReadingReminders();

    if (isoDays.isEmpty) return;

    await requestPermission();

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _readingReminderChannelId,
        _readingReminderChannelName,
        channelDescription: _readingReminderChannelDescription,
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

    for (final isoDay in isoDays) {
      // isoDay: 1=Mon … 7=Sun → DateTime weekday uses same convention
      final scheduledDate = _nextDateForWeekday(isoDay, time);
      final notifId = _readingReminderBaseId + (isoDay - 1);

      await _plugin.zonedSchedule(
        notifId,
        '📚 C\'est l\'heure de lire !',
        'Prends quelques minutes pour avancer dans ton livre',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

      debugPrint(
        'ReadingReminder scheduled: day=$isoDay at ${time.hour}:${time.minute} → $scheduledDate (id=$notifId)',
      );
    }
  }

  /// Cancel all reading reminder notifications.
  Future<void> cancelReadingReminders() async {
    for (var i = 0; i < 7; i++) {
      await _plugin.cancel(_readingReminderBaseId + i);
    }
  }

  /// Returns the next [tz.TZDateTime] for the given ISO weekday and time.
  tz.TZDateTime _nextDateForWeekday(int isoWeekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Advance to the target weekday
    while (scheduled.weekday != isoWeekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // If the target time today has already passed, move to next week
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    return scheduled;
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

    // Re-schedule for next month so the user keeps getting notifications
    MonthlyNotificationService().scheduleNextMonthlyNotification();

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MonthlyWrappedScreen(month: month, year: year),
      ),
    );
  }
}

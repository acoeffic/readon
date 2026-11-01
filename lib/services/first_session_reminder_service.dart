import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'deep_link_service.dart';
import 'notification_permission.dart';

/// Moments proposés à la fin de l'onboarding à ceux qui ne lisent pas tout de
/// suite. Un horaire précis est plus engageant qu'un « On te rappelle ? »
/// oui/non : l'utilisateur décide QUAND il lira, le rappel ne fait que tenir
/// sa promesse.
enum FirstSessionReminderSlot {
  tonight,
  tomorrowMorning,
  tomorrowEvening;

  /// Valeur de la propriété `answer` de l'event PostHog
  /// `onboarding_reminder_prompt` (`none` = « Sans rappel »).
  String get analyticsValue => switch (this) {
        tonight => 'tonight',
        tomorrowMorning => 'tomorrow_morning',
        tomorrowEvening => 'tomorrow_evening',
      };

  /// Instant (heure locale de l'appareil) auquel le rappel doit sonner.
  DateTime resolve(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (this) {
      tonight => DateTime(now.year, now.month, now.day, 21),
      tomorrowMorning => DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8),
      tomorrowEvening =>
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21),
    };
  }

  /// Créneaux réellement proposables à `now`. « Ce soir 21h » disparaît
  /// passé 20h (il serait dans moins d'une heure, voire déjà passé).
  static List<FirstSessionReminderSlot> availableAt(DateTime now) => [
        if (now.hour < 20) tonight,
        tomorrowMorning,
        tomorrowEvening,
      ];
}

/// Rappel local unique « reprends ton livre », posé à la fin de l'onboarding
/// et annulé dès qu'une session démarre.
///
/// S'appuie sur le plugin déjà initialisé au démarrage par
/// `MonthlyNotificationService.initialize()` (fuseau `tz.local` compris) :
/// `FlutterLocalNotificationsPlugin()` renvoie l'instance partagée. Ne
/// présente JAMAIS la popup système : l'appelant l'a déjà fait via
/// `PushNotificationService.promptPermissionAndRegister()`.
class FirstSessionReminderService {
  FirstSessionReminderService._();

  static const int _notificationId = 4001;
  static const String _channelId = 'first_session_reminder';
  static const String _channelName = 'Rappel de première lecture';
  static const String _channelDescription =
      'Un seul rappel pour lancer ta première session de lecture';

  /// Payload reconnu par `MonthlyNotificationService._onNotificationTapped`.
  static const String payload = 'first_session_reminder';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Programme le rappel. Retourne `false` (sans rien poser) si la permission
  /// notifications est absente ou si la planification échoue.
  static Future<bool> schedule({
    required FirstSessionReminderSlot slot,
    required String title,
    required String body,
  }) async {
    try {
      if (!await hasNotificationPermission()) return false;

      final at = tz.TZDateTime.from(slot.resolve(DateTime.now()), tz.local);
      if (!at.isAfter(tz.TZDateTime.now(tz.local))) return false;

      await _plugin.cancel(_notificationId);
      await _plugin.zonedSchedule(
        _notificationId,
        title,
        body,
        at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('FirstSessionReminderService.schedule error: $e');
      return false;
    }
  }

  /// Annule le rappel (appelé au démarrage d'une session : inutile de relancer
  /// quelqu'un qui est déjà en train de lire).
  static Future<void> cancel() async {
    try {
      await _plugin.cancel(_notificationId);
    } catch (e) {
      debugPrint('FirstSessionReminderService.cancel error: $e');
    }
  }

  /// Tap sur la notification : même route que l'e-mail de relance
  /// (`lexday://read`) → écran de démarrage de session sur le livre en cours.
  /// App déjà montée : navigation immédiate ; cold start : route mise en
  /// attente, consommée par MainNavigation.
  static void handleTap() {
    final handler = DeepLinkService.onRoute;
    if (handler != null) {
      handler('read');
    } else {
      DeepLinkService.pendingRoute = 'read';
    }
  }
}

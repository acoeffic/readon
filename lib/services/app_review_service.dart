// lib/services/app_review_service.dart
// Demande d'avis App Store / Play Store via la popup native (package in_app_review).
//
// Garde-fous locaux :
// - jamais avant 1 jour après la première ouverture de l'app ;
// - au maximum une demande tous les 90 jours.
// En plus de ça, c'est Apple/Google qui décident d'afficher ou non la popup
// (limite système iOS : 3 affichages/an/utilisateur, jamais re-montrée si
// l'utilisateur a déjà noté) — donc aucun risque de spammer.
//
// Usage : appeler AppReviewService.maybeRequestReview(trigger: '...') à un
// "moment de fierté" (fin de livre, streak milestone, 3e session terminée).
//
// Volontairement SANS pré-question du type « Tu aimes l'app ? » : les
// consignes Google (et l'esprit des règles Apple) interdisent de filtrer les
// utilisateurs selon leur satisfaction avant d'afficher la popup d'avis.

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReviewService {
  static const String _firstLaunchKey = 'app_review_first_launch_ms';
  static const String _lastRequestKey = 'app_review_last_request_ms';
  static const String _sessionCountKey = 'app_review_completed_sessions';

  static const int _minDaysSinceFirstLaunch = 1;
  static const int _sessionsBeforeAsk = 3;
  static const int _minDaysBetweenRequests = 90;

  /// À appeler au démarrage de l'app : mémorise la date de première ouverture
  /// (ne fait rien si elle est déjà enregistrée).
  static Future<void> recordFirstLaunchIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_firstLaunchKey)) {
        await prefs.setInt(
          _firstLaunchKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      // Non critique — ne doit jamais bloquer le démarrage.
    }
  }

  /// À appeler à chaque session de lecture terminée. À partir de la
  /// [_sessionsBeforeAsk]-ième session, tente la popup d'avis (les garde-fous
  /// ci-dessous évitent toute répétition). Les lecteurs qui ont fait 3
  /// sessions sont ceux qui aiment l'app : c'est le bon moment.
  static Future<void> onSessionCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_sessionCountKey) ?? 0) + 1;
      await prefs.setInt(_sessionCountKey, count);
      if (count >= _sessionsBeforeAsk) {
        await maybeRequestReview(trigger: 'session_$count');
      }
    } catch (_) {
      // Non critique.
    }
  }

  /// Demande l'affichage de la popup d'avis native si les garde-fous le
  /// permettent. [trigger] sert uniquement au log de debug.
  static Future<void> maybeRequestReview({String trigger = 'unknown'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Garde-fou 1 : au moins N jours d'ancienneté.
      final firstLaunch = prefs.getInt(_firstLaunchKey);
      if (firstLaunch == null) {
        // Premier passage (recordFirstLaunchIfNeeded pas encore appelé) :
        // on pose la date et on ne demande pas encore.
        await prefs.setInt(_firstLaunchKey, now);
        return;
      }
      if (now - firstLaunch <
          _minDaysSinceFirstLaunch * Duration.millisecondsPerDay) {
        return;
      }

      // Garde-fou 2 : au plus une demande tous les N jours.
      final lastRequest = prefs.getInt(_lastRequestKey);
      if (lastRequest != null &&
          now - lastRequest <
              _minDaysBetweenRequests * Duration.millisecondsPerDay) {
        return;
      }

      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;

      // On enregistre AVANT la demande : requestReview() ne dit pas si la
      // popup a réellement été affichée, et on préfère sous-solliciter.
      await prefs.setInt(_lastRequestKey, now);
      await inAppReview.requestReview();
      debugPrint('AppReviewService: review requested (trigger=$trigger)');
    } catch (e) {
      debugPrint('AppReviewService: $e');
    }
  }
}

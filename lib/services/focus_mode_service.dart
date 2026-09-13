// lib/services/focus_mode_service.dart
//
// « Mode sans distraction » : guide vers les automatisations Raccourcis iOS
// (LexDay ouvert → Ne pas déranger activé, LexDay fermé → désactivé).
//
// iOS n'expose aucune API pour activer un mode Concentration depuis une app
// tierce — la seule voie 100 % native est une automatisation personnelle que
// l'utilisateur crée lui-même dans Raccourcis. Ce service ne gère donc que
// la *découvrabilité* de la feature :
//
//   * une entrée permanente dans Réglages → Lecture (iOS uniquement) ;
//   * une suggestion affichée UNE SEULE FOIS sur l'écran de résumé de
//     session, à partir de la 2e session terminée sur cet appareil.
//
// Pourquoi la 2e session et pas la 1re : les sollicitations post-première
// session sont déjà prises (permission notifications puis paywall, cf.
// `main_navigation._runValueGatedPrompts`). Empiler une carte de plus sur le
// moment d'activation le plus fragile ferait tout refuser en bloc.
//
// Le comptage est local (SharedPreferences), volontairement : il s'agit de
// cadencer une suggestion UI sur cet appareil, pas de mesurer l'usage — pour
// ça il y a PostHog (`focus_suggestion_shown` / `focus_guide_opened`).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nombre de sessions terminées vues par CET appareil (résumés affichés).
const _kCompletedCountKey = 'focus_local_completed_sessions';

/// La suggestion a déjà été affichée (acceptée OU écartée) — on ne la
/// représente jamais : l'entrée Réglages prend le relais.
const _kSuggestionShownKey = 'focus_suggestion_shown';

class FocusModeService {
  FocusModeService._();
  static final FocusModeService _instance = FocusModeService._();
  factory FocusModeService() => _instance;

  /// La feature n'a de sens que sur iOS (Raccourcis / mode Concentration).
  bool get isSupported => !kIsWeb && Platform.isIOS;

  /// À appeler quand un résumé de session s'affiche. Incrémente le compteur
  /// local et répond : faut-il montrer la suggestion maintenant ?
  ///
  /// `true` au plus une fois dans la vie de l'app sur cet appareil, jamais
  /// avant la 2e session terminée.
  Future<bool> registerCompletedSessionAndCheckSuggestion() async {
    if (!isSupported) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kCompletedCountKey) ?? 0) + 1;
      await prefs.setInt(_kCompletedCountKey, count);

      if (prefs.getBool(_kSuggestionShownKey) == true) return false;
      return count >= 2;
    } catch (e) {
      debugPrint('FocusModeService.registerCompletedSession error: $e');
      return false;
    }
  }

  /// À appeler dès que la carte de suggestion est effectivement affichée,
  /// quelle que soit la suite (tap ou dismiss) — la cartouche est consommée.
  Future<void> markSuggestionShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSuggestionShownKey, true);
    } catch (e) {
      debugPrint('FocusModeService.markSuggestionShown error: $e');
    }
  }
}

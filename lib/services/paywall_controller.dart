// lib/services/paywall_controller.dart
//
// Centralise les déclencheurs du paywall :
//
// 1. Fin d'onboarding : `markPendingAfterOnboarding()` est appelé juste avant
//    `pushAndRemoveUntil(MainNavigation)` dans OnboardingPage. MainNavigation
//    appelle ensuite [maybeShowOnAppOpen], qui détecte le flag pending et
//    présente le paywall.
//
// 2. Récurrent : sur chaque cold-launch authentifié atterrissant sur
//    MainNavigation, on incrémente un compteur. Une connexion sur deux
//    (compte 2, 4, 6, ...), on re-propose le paywall aux non-premium.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_paywall_service.dart';
import 'subscription_service.dart';

class PaywallController {
  static const _kOnboardingPendingKey = 'paywall_pending_after_onboarding';
  static const _kAppOpenCountKey = 'paywall_app_open_count';

  /// À appeler quand l'onboarding vient de se terminer, juste avant la
  /// navigation vers MainNavigation. Pose le flag qui déclenchera la
  /// présentation du paywall au prochain `maybeShowOnAppOpen`.
  static Future<void> markPendingAfterOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingPendingKey, true);
    // Réinitialise le compteur pour que la 1ère relance "normale" ne soit
    // pas considérée comme une présentation récurrente (les deux triggers
    // doivent rester distincts).
    await prefs.setInt(_kAppOpenCountKey, 0);
  }

  /// À appeler depuis MainNavigation après le premier frame. Décide si on
  /// présente le paywall en fonction :
  ///   - du flag pending (onboarding terminé) → on présente,
  ///   - sinon du compteur de cold-launch → 1 sur 2 chez les non-premium.
  ///
  /// Si une autre route est empilée par-dessus MainNavigation (ex.: première
  /// session de lecture lancée juste après l'onboarding), on n'affiche rien
  /// — le flag reste actif et se déclenchera au prochain cold-launch.
  static Future<void> maybeShowOnAppOpen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Trigger 1 : sortie d'onboarding (priorité).
    if (prefs.getBool(_kOnboardingPendingKey) == true) {
      if (!context.mounted) return;
      if (!_canPresentNow(context)) return;
      await prefs.setBool(_kOnboardingPendingKey, false);
      if (!context.mounted) return;
      await NativePaywallService.present(context);
      return;
    }

    // Trigger 2 : 1 connexion sur 2 pour les non-premium.
    final isPremium = await SubscriptionService().isPremium();
    if (isPremium) return;

    final next = (prefs.getInt(_kAppOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_kAppOpenCountKey, next);

    // Skip 1, show 1, skip 1, show 1 — on présente sur les pairs (2, 4, …),
    // ce qui laisse une connexion de "respiration" après l'onboarding paywall.
    if (next % 2 != 0) return;

    if (!context.mounted) return;
    if (!_canPresentNow(context)) return;
    await NativePaywallService.present(context);
  }

  /// `false` si une autre route est empilée par-dessus MainNavigation
  /// (ex. : page de lecture poussée juste après l'onboarding).
  static bool _canPresentNow(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }
}

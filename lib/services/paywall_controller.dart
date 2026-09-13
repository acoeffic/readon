// lib/services/paywall_controller.dart
//
// Centralise les déclencheurs du paywall.
//
// Règle de base : **on ne présente jamais le paywall à quelqu'un qui n'a pas
// encore terminé une session de lecture.** Tant que l'utilisateur n'a pas vu
// ce que l'app fait, lui demander de payer ne convertit pas et coûte
// l'activation (audit entonnoir du 15/08/2026 : le paywall était la première
// chose vue en sortant de l'onboarding).
//
// 1. Première session terminée : au prochain retour sur MainNavigation avec
//    `has_completed_first_session = true`, on présente le paywall une fois.
// 2. Récurrent : ensuite seulement, chez les non-premium, avec un **espacement
//    croissant** (2 → 5 → 15 lancements), un **écart minimum de 3 jours**, et
//    un **arrêt définitif après 4 présentations** sans conversion.
//
//    Avant le 18/08/2026 c'était « une connexion sur deux », à vie et sans
//    plafond : ~15 paywalls par mois pour un lecteur quotidien, indéfiniment.
//    Quelqu'un qui a refusé 4 fois ne convertit pas parce qu'on insiste une
//    5e — en revanche il désinstalle. Le paywall reste atteignable partout
//    ailleurs (gates premium, écran d'abonnement) : on ne retire que la
//    sollicitation non demandée.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'native_paywall_service.dart';
import 'subscription_service.dart';

class PaywallController {
  /// Le paywall "post-première session" a déjà été présenté.
  static const _kFirstSessionShownKey = 'paywall_shown_after_first_session';

  /// Lancements comptés **depuis le dernier paywall** (remis à 0 à chaque
  /// présentation), et non depuis l'installation.
  static const _kAppOpenCountKey = 'paywall_app_open_count';

  /// Nombre de paywalls récurrents déjà présentés (= nombre de refus, un
  /// achat sortant plus haut via `isPremium`).
  static const _kRecurringShownCountKey = 'paywall_recurring_shown_count';

  /// Horodatage du dernier paywall présenté (epoch ms).
  static const _kLastShownAtKey = 'paywall_last_shown_at';

  /// Lancements requis avant le prochain paywall, selon le nombre de refus
  /// déjà encaissés. Au-delà de la liste, on garde le dernier écart.
  static const _kLaunchGaps = <int>[2, 5, 15];

  /// Nombre maximum de paywalls récurrents. Ensuite, plus rien.
  static const _kMaxRecurringPresentations = 4;

  /// Écart minimum entre deux paywalls, quel que soit le nombre de
  /// lancements : un dimanche à dix ouvertures ne doit pas en déclencher deux.
  static const _kMinInterval = Duration(days: 3);

  /// Ancienne clé (paywall à la sortie de l'onboarding). Conservée uniquement
  /// pour être purgée chez les utilisateurs déjà installés — plus jamais lue
  /// comme déclencheur.
  static const _kLegacyOnboardingPendingKey =
      'paywall_pending_after_onboarding';

  /// À appeler depuis MainNavigation après le premier frame.
  ///
  /// [hasCompletedFirstSession] vient de `profiles.has_completed_first_session`
  /// (voir `ContactsService.hasCompletedFirstSession`). Tant qu'il est `false`,
  /// aucun paywall n'est présenté et le compteur de lancements n'est même pas
  /// incrémenté : le cycle "1 sur 2" ne démarre qu'une fois la valeur délivrée.
  ///
  /// Si une autre route est empilée par-dessus MainNavigation (résumé de
  /// session, page de lecture…), on n'affiche rien — la prochaine ouverture
  /// réessaiera.
  ///
  /// Retourne `true` si le paywall a effectivement été présenté, afin que
  /// l'appelant n'enchaîne pas une autre sollicitation dans le même
  /// lancement.
  static Future<bool> maybeShowOnAppOpen(
    BuildContext context, {
    required bool hasCompletedFirstSession,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Migration des installations existantes : la présence de l'ancienne clé
    // signifie que cet utilisateur a déjà eu son paywall de sortie
    // d'onboarding. On considère donc le paywall "première session" comme
    // déjà présenté, pour ne pas le lui resservir une fois de plus au
    // premier lancement après la mise à jour.
    if (prefs.containsKey(_kLegacyOnboardingPendingKey)) {
      await prefs.remove(_kLegacyOnboardingPendingKey);
      if (!prefs.containsKey(_kFirstSessionShownKey)) {
        await prefs.setBool(_kFirstSessionShownKey, true);
      }
    }

    // Aucune session terminée → aucun paywall, aucun comptage.
    if (!hasCompletedFirstSession) return false;

    final isPremium = await SubscriptionService().isPremium();
    if (isPremium) return false;

    // Trigger 1 : première session de lecture terminée (une seule fois).
    if (prefs.getBool(_kFirstSessionShownKey) != true) {
      if (!context.mounted) return false;
      if (!_canPresentNow(context)) return false;
      await prefs.setBool(_kFirstSessionShownKey, true);
      // Laisse une connexion de "respiration" avant le cycle récurrent.
      await prefs.setInt(_kAppOpenCountKey, 0);
      // Le garde-fou des 3 jours court aussi à partir de ce paywall-là.
      await prefs.setInt(
          _kLastShownAtKey, DateTime.now().millisecondsSinceEpoch);
      if (!context.mounted) return false;
      await _present(context, trigger: 'first_session_completed');
      return true;
    }

    // Trigger 2 : récurrent, espacé, plafonné.
    await _migrateRecurringState(prefs);

    final shownCount = prefs.getInt(_kRecurringShownCountKey) ?? 0;
    if (shownCount >= _kMaxRecurringPresentations) return false;

    final next = (prefs.getInt(_kAppOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_kAppOpenCountKey, next);

    final gap = _kLaunchGaps[
        shownCount < _kLaunchGaps.length ? shownCount : _kLaunchGaps.length - 1];
    if (next < gap) return false;

    // Garde-fou temporel : indépendant du nombre de lancements.
    final lastShownMs = prefs.getInt(_kLastShownAtKey);
    if (lastShownMs != null) {
      final since = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs));
      if (since < _kMinInterval) return false;
    }

    if (!context.mounted) return false;
    if (!_canPresentNow(context)) return false;

    // On n'incrémente qu'au moment où le paywall est réellement présenté :
    // un retour bloqué par `_canPresentNow` ne doit pas consommer un cran.
    await prefs.setInt(_kAppOpenCountKey, 0);
    await prefs.setInt(_kRecurringShownCountKey, shownCount + 1);
    await prefs.setInt(
        _kLastShownAtKey, DateTime.now().millisecondsSinceEpoch);

    await _present(
      context,
      trigger: 'recurring_app_open',
      presentationIndex: shownCount + 1,
    );
    return true;
  }

  /// Installations existantes : elles arrivent avec un `paywall_app_open_count`
  /// cumulé depuis l'installation (parfois des dizaines) et aucun compteur de
  /// présentations. Sans ce rattrapage, elles repartiraient pour 4 paywalls
  /// alors qu'elles en ont déjà encaissé beaucoup. On les positionne au
  /// deuxième cran et on repart d'un compteur de lancements propre.
  static Future<void> _migrateRecurringState(SharedPreferences prefs) async {
    if (prefs.containsKey(_kRecurringShownCountKey)) return;

    final legacyCount = prefs.getInt(_kAppOpenCountKey) ?? 0;
    await prefs.setInt(_kRecurringShownCountKey, legacyCount >= 2 ? 2 : 0);
    await prefs.setInt(_kAppOpenCountKey, 0);
  }

  /// Présente le paywall et logue l'event PostHog (non bloquant) — sert à
  /// mesurer combien de paywalls sont réellement présentés, et sur quel
  /// déclencheur.
  static Future<void> _present(
    BuildContext context, {
    required String trigger,
    int? presentationIndex,
  }) async {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.paywallShown,
      properties: {
        'trigger': trigger,
        // Rang de la présentation : permet de vérifier dans PostHog si les
        // conversions viennent du 1er paywall ou des suivants — et donc si
        // les 3 crans suivants servent à quelque chose.
        if (presentationIndex != null) 'presentation_index': presentationIndex,
      },
    ));
    await NativePaywallService.present(context);
  }

  /// `false` si une autre route est empilée par-dessus MainNavigation
  /// (ex. : résumé de session poussé juste après la lecture).
  static bool _canPresentNow(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }
}

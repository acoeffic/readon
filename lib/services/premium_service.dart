// lib/services/premium_service.dart
// @Deprecated: Utiliser SubscriptionService à la place.
// Ce fichier sert de bridge pendant la migration.

import 'subscription_service.dart';

@Deprecated('Utiliser SubscriptionService à la place')
class PremiumService {
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Vérifier si l'utilisateur est premium
  /// Redirige vers SubscriptionService.isPremium()
  Future<bool> isPremium() async {
    return _subscriptionService.isPremium();
  }

  /// Invalider le cache — no-op, géré par RevenueCat
  void invalidateCache() {
    // RevenueCat gère son propre cache
  }
}

// lib/providers/subscription_provider.dart
// Provider réactif pour le statut d'abonnement premium

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();

  bool _isPremium = false;
  String _status = 'free';
  String? _productId;
  DateTime? _expiresAt;
  bool _isLoading = true;

  bool get isPremium => _isPremium;
  String get status => _status;
  String? get productId => _productId;
  DateTime? get expiresAt => _expiresAt;
  bool get isLoading => _isLoading;
  bool get isTrial => _status == 'trial';
  bool get isExpired => _status == 'expired';

  SubscriptionProvider() {
    _init();
  }

  Future<void> _init() async {
    await refreshStatus();
    // Pas de listener RevenueCat en mode dev-premium
    if (!_service.isDevPremium) {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final active =
        info.entitlements.active.containsKey(SubscriptionService.entitlementId);

    if (active != _isPremium) {
      _isPremium = active;
      _status = active ? 'premium' : 'expired';

      final entitlement =
          info.entitlements.active[SubscriptionService.entitlementId];
      if (entitlement != null) {
        _productId = entitlement.productIdentifier;
        _expiresAt = entitlement.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null;
        _status = entitlement.periodType == PeriodType.trial
            ? 'trial'
            : 'premium';
      }

      notifyListeners();
    }
  }

  /// Recharger le statut depuis RevenueCat/Supabase
  Future<void> refreshStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final subStatus = await _service.getSubscriptionStatus();
      _isPremium = subStatus.isPremium;
      _status = subStatus.status;
      _productId = subStatus.productId;
      _expiresAt = subStatus.expiresAt;
    } catch (e) {
      debugPrint('SubscriptionProvider refresh error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Appeler après un achat réussi
  Future<void> onPurchaseCompleted() async {
    await refreshStatus();
  }

  @override
  void dispose() {
    if (!_service.isDevPremium) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }
}

// lib/services/subscription_service.dart
// Service pour gérer les abonnements premium via RevenueCat

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SubscriptionStatus {
  final bool isPremium;
  final String status; // free, trial, premium, expired, billing_issue
  final String? productId;
  final DateTime? expiresAt;

  const SubscriptionStatus({
    required this.isPremium,
    required this.status,
    this.productId,
    this.expiresAt,
  });

  factory SubscriptionStatus.free() => const SubscriptionStatus(
        isPremium: false,
        status: 'free',
      );
}

class SubscriptionService {
  static String get _apiKeyIOS => Env.revenueCatApiKeyIOS;
  static String get _apiKeyAndroid => Env.revenueCatApiKeyAndroid;

  // Product identifiers (configurés dans RevenueCat dashboard)
  static const monthlyProductId = 'readon_premium_monthly';
  static const annualProductId = 'readon_premium_annual';
  static const entitlementId = 'premium';

  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton (cohérent avec les autres services du projet)
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _initialized = false;

  /// `true` quand on court-circuite RevenueCat (dev/test).
  bool get isDevPremium => Env.devForcePremium;

  /// Initialiser le SDK RevenueCat — appeler une fois depuis main.dart
  Future<void> initialize() async {
    if (_initialized) return;

    // En mode dev-premium, on skip entièrement RevenueCat
    if (isDevPremium) {
      _initialized = true;
      debugPrint('⚡ DEV_FORCE_PREMIUM activé — RevenueCat ignoré');
      return;
    }

    try {
      final PurchasesConfiguration configuration;
      if (Platform.isIOS || Platform.isMacOS) {
        configuration = PurchasesConfiguration(_apiKeyIOS);
      } else if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_apiKeyAndroid);
      } else {
        debugPrint('RevenueCat: plateforme non supportée');
        return;
      }

      await Purchases.configure(configuration);

      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Si l'utilisateur est déjà connecté, associer son ID
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await loginUser(user.id);
      }

      _initialized = true;
      debugPrint('RevenueCat initialisé');
    } catch (e) {
      debugPrint('Erreur init RevenueCat: $e');
    }
  }

  /// Associer l'utilisateur Supabase à RevenueCat
  Future<void> loginUser(String userId) async {
    if (isDevPremium) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('Erreur loginUser RevenueCat: $e');
    }
  }

  /// Déconnecter de RevenueCat
  Future<void> logoutUser() async {
    if (isDevPremium) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('Erreur logoutUser RevenueCat: $e');
    }
  }

  /// Récupérer les offres disponibles (mensuel, annuel)
  Future<Offerings?> getOfferings() async {
    if (isDevPremium) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      debugPrint('Erreur getOfferings: $e');
      return null;
    }
  }

  /// Acheter un package
  Future<bool> purchasePackage(Package package) async {
    if (isDevPremium) return true;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium =
          customerInfo.entitlements.active.containsKey(entitlementId);

      return isPremium;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Achat annulé par l\'utilisateur');
      } else {
        debugPrint('Erreur achat: $e');
      }
      return false;
    }
  }

  /// Restaurer les achats (App Store / Play Store)
  Future<bool> restorePurchases() async {
    if (isDevPremium) return true;
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremium =
          customerInfo.entitlements.active.containsKey(entitlementId);

      return isPremium;
    } catch (e) {
      debugPrint('Erreur restore: $e');
      return false;
    }
  }

  /// Vérifier le statut premium (RC SDK source de vérité, fallback Supabase)
  Future<bool> isPremium() async {
    if (isDevPremium) return true;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      debugPrint('Erreur isPremium RC, fallback Supabase: $e');
      // Fallback Supabase
      try {
        final result = await _supabase.rpc('check_premium_status');
        return result['is_premium'] as bool? ?? false;
      } catch (e2) {
        debugPrint('Erreur fallback Supabase: $e2');
        return false;
      }
    }
  }

  /// Obtenir les détails complets de l'abonnement
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    if (isDevPremium) {
      return const SubscriptionStatus(
        isPremium: true,
        status: 'premium',
        productId: 'dev_force_premium',
      );
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[entitlementId];

      if (entitlement != null) {
        return SubscriptionStatus(
          isPremium: true,
          status: entitlement.periodType == PeriodType.trial
              ? 'trial'
              : 'premium',
          productId: entitlement.productIdentifier,
          expiresAt: entitlement.expirationDate != null
              ? DateTime.parse(entitlement.expirationDate!)
              : null,
        );
      }

      return SubscriptionStatus.free();
    } catch (e) {
      debugPrint('Erreur getSubscriptionStatus: $e');
      // Fallback Supabase
      try {
        final result = await _supabase.rpc('check_premium_status');
        return SubscriptionStatus(
          isPremium: result['is_premium'] as bool? ?? false,
          status: result['status'] as String? ?? 'free',
          expiresAt: result['premium_until'] != null
              ? DateTime.tryParse(result['premium_until'] as String)
              : null,
        );
      } catch (e2) {
        debugPrint('Erreur fallback status: $e2');
        return SubscriptionStatus.free();
      }
    }
  }

}

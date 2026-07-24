// lib/services/subscription_service.dart
// Service pour gérer les abonnements premium via RevenueCat

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Détails enrichis pour l'écran "Gérer mon abonnement".
class SubscriptionDetails {
  final bool isPremium;
  final String status;
  final String? productId;
  final DateTime? originalPurchaseDate;
  final DateTime? latestPurchaseDate;
  final DateTime? expiresAt;
  final bool willRenew;
  final String? store; // 'APP_STORE', 'PLAY_STORE', etc.

  const SubscriptionDetails({
    required this.isPremium,
    required this.status,
    required this.willRenew,
    this.productId,
    this.originalPurchaseDate,
    this.latestPurchaseDate,
    this.expiresAt,
    this.store,
  });

  factory SubscriptionDetails.free() => const SubscriptionDetails(
        isPremium: false,
        status: 'free',
        willRenew: false,
      );
}

class SubscriptionService {
  static String get _apiKeyIOS => Env.revenueCatApiKeyIOS;
  static String get _apiKeyAndroid => Env.revenueCatApiKeyAndroid;

  // Product identifiers (configurés dans RevenueCat dashboard)
  static const monthlyProductId = 'fr.lexday.premium.monthly';
  static const annualProductId = 'fr.lexday.premium.yearly';
  static const entitlementId = 'LexDay SAS Pro';

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
        configuration = PurchasesConfiguration(_apiKeyIOS)
          // Observer mode iOS : la vue SwiftUI SubscriptionStoreView réalise
          // l'achat en StoreKit 2 direct ; RevenueCat observe et synchronise
          // l'entitlement (webhook Supabase inchangé).
          ..purchasesAreCompletedBy = PurchasesAreCompletedByMyApp(
            storeKitVersion: StoreKitVersion.storeKit2,
          )
          ..storeKitVersion = StoreKitVersion.storeKit2;
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
      final result = await Purchases.purchasePackage(package);
      final customerInfo = result.customerInfo;
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

  /// Ouvre l'écran natif de gestion des abonnements (App Store / Play Store).
  /// C'est l'unique moyen permis par les stores pour se désabonner.
  /// Utilise le `managementURL` fourni par RevenueCat (retourne le bon lien
  /// store selon la plateforme) ; fallback sur l'URL générique du compte.
  Future<void> showManageSubscriptions() async {
    if (isDevPremium) {
      debugPrint('DEV_FORCE_PREMIUM: showManageSubscriptions no-op');
      return;
    }
    Uri? target;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final managementUrl = customerInfo.managementURL;
      if (managementUrl != null && managementUrl.isNotEmpty) {
        target = Uri.tryParse(managementUrl);
      }
    } catch (e) {
      debugPrint('managementURL fetch failed: $e');
    }
    target ??= Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    try {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('launchUrl manage subs failed: $e');
    }
  }

  /// Détails enrichis (date d'abonnement initial, auto-renew, store…) pour
  /// l'écran "Gérer mon abonnement".
  Future<SubscriptionDetails> getSubscriptionDetails() async {
    if (isDevPremium) {
      return SubscriptionDetails(
        isPremium: true,
        status: 'premium',
        productId: 'dev_force_premium',
        willRenew: true,
        originalPurchaseDate: DateTime.now(),
      );
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[entitlementId];
      if (entitlement == null) return SubscriptionDetails.free();

      return SubscriptionDetails(
        isPremium: true,
        status: entitlement.periodType == PeriodType.trial
            ? 'trial'
            : 'premium',
        productId: entitlement.productIdentifier,
        willRenew: entitlement.willRenew,
        originalPurchaseDate:
            DateTime.tryParse(entitlement.originalPurchaseDate),
        latestPurchaseDate:
            DateTime.tryParse(entitlement.latestPurchaseDate),
        expiresAt: entitlement.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null,
        store: entitlement.store.name,
      );
    } catch (e) {
      debugPrint('Erreur getSubscriptionDetails: $e');
      return SubscriptionDetails.free();
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

// lib/services/native_paywall_service.dart
// Router de paywall : sur iOS 17+ on présente la vue native Apple
// `SubscriptionStoreView` (conforme aux dernières directives App Store) ;
// sinon on retombe sur la `UpgradePage` Flutter existante.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feature_flags.dart';
import '../pages/profile/upgrade_page.dart';
import '../services/subscription_service.dart';

class NativePaywallService {
  static const _channel = MethodChannel('fr.lexday.app/paywall');

  static bool? _cachedAvailability;

  /// Retourne `true` si le paywall natif iOS 17+ est dispo sur cet appareil.
  static Future<bool> isNativeAvailable() async {
    if (!Platform.isIOS) return false;
    if (_cachedAvailability != null) return _cachedAvailability!;
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable');
      _cachedAvailability = ok == true;
      return _cachedAvailability!;
    } catch (e) {
      debugPrint('NativePaywallService.isNativeAvailable failed: $e');
      _cachedAvailability = false;
      return false;
    }
  }

  /// Présente le paywall natif Apple si possible, sinon push la page Flutter.
  /// Le `highlightedFeature` n'est utilisé qu'en fallback Flutter — la vue
  /// native Apple n'expose pas ce concept (elle affiche toujours le paywall
  /// global LexDay Premium).
  static Future<void> present(
    BuildContext context, {
    Feature? highlightedFeature,
  }) async {
    if (await isNativeAvailable()) {
      try {
        await _channel.invokeMethod<bool>('present', {
          'productIDs': <String>[
            SubscriptionService.monthlyProductId,
            SubscriptionService.annualProductId,
          ],
        });
        return;
      } catch (e) {
        debugPrint('Native paywall failed, fallback Flutter: $e');
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpgradePage(highlightedFeature: highlightedFeature),
      ),
    );
  }
}

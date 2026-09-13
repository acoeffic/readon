// lib/providers/guest_mode_provider.dart
// Provider pour le mode invité : permet de consulter les contenus publics
// (profils publics, clubs publics, discussions publiques) sans compte.
//
// Apple App Store guideline 5.1.1 : ne pas forcer la création de compte pour
// accéder aux fonctionnalités principales qui ne le nécessitent pas.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';

class GuestModeProvider with ChangeNotifier {
  static const _prefsKey = 'guest_mode_active';

  bool _isGuest = false;
  bool _initialized = false;

  bool get isGuest => _isGuest;
  bool get initialized => _initialized;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool(_prefsKey) ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> enterGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    _isGuest = true;
    // Les invités ne laissent aucune trace en base : sans cet event, on ne
    // sait pas combien de téléchargements finissent ici plutôt qu'en compte.
    // PostHog est configuré en `personProfiles = always`, les events anonymes
    // remontent donc bien.
    unawaited(AnalyticsService().track(AnalyticsEvent.guestModeEntered));
    // Propriété de personne : rend TOUS les events de la session filtrables
    // par `is_guest` dans PostHog, y compris les `$screen` automatiques du
    // PosthogObserver. Sans elle, on saurait qu'un invité est entré mais pas
    // ce qu'il a regardé ensuite.
    unawaited(AnalyticsService().setUserProperties({'is_guest': true}));
    notifyListeners();
  }

  Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final wasGuest = _isGuest;
    await prefs.setBool(_prefsKey, false);
    _isGuest = false;
    // `exitGuestMode()` est aussi appelée sur des chemins où l'utilisateur
    // n'était pas invité : on ne compte que les vraies sorties, sinon le taux
    // de conversion est faussé par le dénominateur.
    if (wasGuest) {
      unawaited(AnalyticsService().track(AnalyticsEvent.guestModeExited));
    }
    unawaited(AnalyticsService().setUserProperties({'is_guest': false}));
    notifyListeners();
  }
}

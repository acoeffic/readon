// lib/providers/guest_mode_provider.dart
// Provider pour le mode invité : permet de consulter les contenus publics
// (profils publics, clubs publics, discussions publiques) sans compte.
//
// Apple App Store guideline 5.1.1 : ne pas forcer la création de compte pour
// accéder aux fonctionnalités principales qui ne le nécessitent pas.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    notifyListeners();
  }

  Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    _isGuest = false;
    notifyListeners();
  }
}

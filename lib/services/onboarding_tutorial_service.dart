// lib/services/onboarding_tutorial_service.dart
//
// Tracks whether the new-user onboarding tutorial (showcase coach marks)
// has already been shown. Backed by SharedPreferences so it survives app
// restarts.

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTutorialService {
  static const _kMainTutorialSeen = 'onboarding_main_tutorial_seen_v2';

  Future<bool> hasSeenMainTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMainTutorialSeen) ?? false;
  }

  Future<void> markMainTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMainTutorialSeen, true);
  }

  Future<void> resetMainTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMainTutorialSeen);
  }
}

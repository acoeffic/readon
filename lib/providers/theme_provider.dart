import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_variant.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode_v2';
  static const String _variantKey = 'theme_variant_v1';
  ThemeMode _themeMode = ThemeMode.system;
  ThemeVariantPalette _variant = ThemeVariants.sage;

  ThemeProvider() {
    _loadThemeMode();
    _loadVariant();
  }

  ThemeMode get themeMode => _themeMode;
  ThemeVariantPalette get variant => _variant;

  /// Returns true if the effective theme is dark (resolves system mode).
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    if (stored != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    } else {
      // Migrate from old boolean key
      final oldIsDark = prefs.getBool('theme_mode');
      if (oldIsDark != null) {
        _themeMode = oldIsDark ? ThemeMode.dark : ThemeMode.light;
        await prefs.setString(_themeKey, _themeMode.name);
        await prefs.remove('theme_mode');
      }
    }
    notifyListeners();
  }

  Future<void> _loadVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_variantKey);
    _variant = ThemeVariants.fromId(stored);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setVariant(ThemeVariantPalette variant) async {
    if (_variant.id == variant.id) return;

    _variant = variant;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_variantKey, variant.id);
  }

  /// Reset au défaut (Sage). Utile lors de la perte du statut Premium.
  Future<void> resetToDefault() async {
    if (_variant.id == ThemeVariants.sage.id) return;
    await setVariant(ThemeVariants.sage);
  }
}

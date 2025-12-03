// theme/app_theme.dart
// Thème Flutter extrait et simplifié depuis votre fichier monolithique

import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2EBFA3);
  static const accentLight = Color(0xFFE8FFFA);
  static const bgLight = Color(0xFFF6F6F6);
  static const white = Colors.white;
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF6A6A6A);
  static const border = Color(0xFFE2E2E2);
  static const error = Color(0xFFEB5757);
}

class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 20.0;
  static const xl = 28.0;
}

class AppRadius {
  static const s = 6.0;
  static const m = 10.0;
  static const l = 18.0;
  static const pill = 32.0;
}

class AppTheme {
  static ThemeData light = ThemeData(
    scaffoldBackgroundColor: AppColors.bgLight,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    useMaterial3: true,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

/// 🎨 Palette ReadOn
class AppColors {
  static const primary = Color(0xFF44E3B4); // Vert menthe “Progression”
  static const accentLight = Color(0xFFB9F5E4); // Vert pastel “Encouragement”
  static const white = Color(0xFFFFFFFF); // Blanc pur “Clarté”
  static const bgLight = Color(0xFFF5F6F7); // Gris clair “Fond secondaire”
  static const textPrimary = Color(0xFF212121); // Anthracite “Lecture”
  static const textSecondary = Color(0xFF8C8C8C); // Gris doux “Sérénité”
  static const focus = Color(0xFF6A5AE0); // Violet doux “Focus”
  static const success = primary;
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const border = Color(0xFFE0E0E0);
}

/// 🌈 Espacements
class AppSpace {
  static const xs = 8.0;
  static const s = 12.0;
  static const m = 16.0;
  static const l = 20.0;
  static const xl = 28.0;
  static const xxl = 36.0;
}

/// 🧩 Rayons de bordure
class AppRadius {
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

/// ✨ Thème principal ReadOn — Flutter 3.22+
class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.focus,
      background: AppColors.white,
      surface: AppColors.bgLight,
      brightness: Brightness.light,
    ),

    // 🧭 AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    // 📝 Typographie
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        fontSize: 42,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    ),

    // 🧱 Cards
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      margin: const EdgeInsets.all(AppSpace.m),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
    ),

    // 🔘 Navigation bar
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.accentLight,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 24,
          );
        },
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) {
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          );
        },
      ),
    ),

    // ✏️ Champs de texte
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),

    dividerColor: AppColors.border,
  );
}

// theme/app_theme.dart
// Thème Flutter extrait et simplifié depuis votre fichier monolithique

import 'package:flutter/material.dart';

class AppColors {
  // Colors used in both themes
  static const primary = Color(0xFF7FA497);
  static const error = Color(0xFFEB5757);
  static const feedHeader = Color(0xFF7FA497);

  // Light theme colors
  static const accentLight = Color(0xFFE8FFFA);
  static const bgLight = Color(0xFFF6F1EC);
  static const white = Colors.white;
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF6A6A6A);
  static const border = Color(0xFFE2E2E2);

  // Library screen colors
  static const libraryBg = Color(0xFFFAF3E8);
  static const sageGreen = Color(0xFF6B988D);
  static const gold = Color(0xFFC6A85A);

  // Dark theme colors
  static const accentDark = Color(0xFF1A4D44);
  static const bgDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const textPrimaryDark = Color(0xFFE0E0E0);
  static const textSecondaryDark = Color(0xFF9E9E9E);
  static const borderDark = Color(0xFF3A3A3A);
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

// ---------------------------------------------------------------------------
// Extension for easy theme-aware color access: context.appColors.cardBg
// ---------------------------------------------------------------------------
class AppThemeColors {
  final Brightness brightness;
  const AppThemeColors._(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  // Backgrounds
  Color get scaffoldBg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get cardBg => isDark ? AppColors.surfaceDark : Colors.white;
  Color get accent => isDark ? AppColors.accentDark : AppColors.accentLight;
  Color get libraryBg => isDark ? const Color(0xFF1A1814) : AppColors.libraryBg;

  // Text
  Color get textPrimary => isDark ? AppColors.textPrimaryDark : Colors.black;
  Color get textSecondary => isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  // Borders & dividers
  Color get border => isDark ? AppColors.borderDark : AppColors.border;
  Color get divider => isDark ? AppColors.borderDark : const Color(0xFFE8E8E8);

  // Pill / chip backgrounds (for reactions, tags, etc.)
  Color get pillBg => isDark ? const Color(0xFF2A2520) : const Color(0xFFF0EBE1);

  // Snackbar
  Color get snackbarSuccess => isDark ? const Color(0xFF1B5E20) : const Color(0xFF4CAF50);
  Color get snackbarError => isDark ? const Color(0xFFB71C1C) : AppColors.error;

  // Misc
  Color get shadow => isDark ? Colors.black54 : Colors.black12;
  Color get shimmerBase => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  Color get shimmerHighlight => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);
}

extension AppThemeColorsExtension on BuildContext {
  AppThemeColors get appColors =>
      AppThemeColors._(Theme.of(this).brightness);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ---------------------------------------------------------------------------
// Theme definitions
// ---------------------------------------------------------------------------
class AppTheme {
  static ThemeData light = _buildTheme(Brightness.light);
  static ThemeData dark = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = AppThemeColors._(brightness);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      surface: isDark ? AppColors.surfaceDark : null,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.scaffoldBg,
      colorScheme: colorScheme,
      useMaterial3: true,

      // Text
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.textPrimaryDark : Colors.black87,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffoldBg,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),

      // Card
      cardTheme: CardThemeData(
        color: colors.cardBg,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: isDark
              ? BorderSide(color: colors.border, width: 0.5)
              : BorderSide.none,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: colors.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.black87,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 0.5,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurface,
        textColor: colors.textPrimary,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: colors.pillBg,
        selectedColor: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      // Misc
      cardColor: colors.cardBg,
      dividerColor: colors.divider,
    );
  }
}

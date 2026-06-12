// theme/app_theme.dart
// Thème Flutter extrait et simplifié depuis votre fichier monolithique

import 'package:flutter/material.dart';
import 'theme_variant.dart';

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
// Extension pour accès théme-aware : context.appColors.cardBg
// Implémentée comme `ThemeExtension` pour porter aussi le `variant` actif
// dans le ThemeData — sinon `context.appColors` ne dépendrait que de la
// luminosité et tous les thèmes auraient le même fond.
// ---------------------------------------------------------------------------
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Brightness brightness;
  final ThemeVariantPalette variant;

  const AppThemeColors._(this.brightness, this.variant);

  bool get isDark => brightness == Brightness.dark;

  // Couleurs variant (utilisez ces getters au lieu de AppColors.primary)
  Color get primary => variant.primary;
  Color get primaryDeep => variant.primaryDeep;
  Color get variantAccent => variant.accent;

  // Backgrounds (changent par thème — gros impact visuel)
  Color get scaffoldBg => isDark ? variant.scaffoldBgDark : variant.scaffoldBgLight;
  Color get cardBg => isDark ? variant.cardBgDark : variant.cardBgLight;
  Color get accent => isDark ? variant.accentBgDark : variant.accentBgLight;
  Color get libraryBg => isDark ? variant.libraryBgDark : variant.libraryBgLight;
  Color get pillBg => isDark ? variant.pillBgDark : variant.pillBgLight;

  // Text
  Color get textPrimary => isDark ? AppColors.textPrimaryDark : Colors.black;
  Color get textSecondary => isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  // Borders & dividers
  Color get border => isDark ? AppColors.borderDark : AppColors.border;
  Color get divider => isDark ? AppColors.borderDark : const Color(0xFFE8E8E8);

  // Snackbar
  Color get snackbarSuccess => isDark ? const Color(0xFF1B5E20) : const Color(0xFF4CAF50);
  Color get snackbarError => isDark ? const Color(0xFFB71C1C) : AppColors.error;

  // Misc
  Color get shadow => isDark ? Colors.black54 : Colors.black12;
  Color get shimmerBase => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  Color get shimmerHighlight => isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

  @override
  AppThemeColors copyWith({
    Brightness? brightness,
    ThemeVariantPalette? variant,
  }) {
    return AppThemeColors._(
      brightness ?? this.brightness,
      variant ?? this.variant,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    // Pas d'interpolation entre thèmes : on bascule franchement à mi-chemin.
    if (other is! AppThemeColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeColorsExtension on BuildContext {
  AppThemeColors get appColors {
    final ext = Theme.of(this).extension<AppThemeColors>();
    if (ext != null) return ext;
    // Fallback safety net si l'extension n'est pas enregistrée (tests, etc.)
    return AppThemeColors._(Theme.of(this).brightness, ThemeVariants.sage);
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ---------------------------------------------------------------------------
// Theme definitions
// ---------------------------------------------------------------------------
class AppTheme {
  /// Light theme avec un variant donné. Default = Sage (compat).
  static ThemeData light({ThemeVariantPalette? variant}) =>
      _buildTheme(Brightness.light, variant ?? ThemeVariants.sage);

  /// Dark theme avec un variant donné.
  static ThemeData dark({ThemeVariantPalette? variant}) =>
      _buildTheme(Brightness.dark, variant ?? ThemeVariants.sage);

  static ThemeData _buildTheme(
    Brightness brightness,
    ThemeVariantPalette variant,
  ) {
    final isDark = brightness == Brightness.dark;
    final colors = AppThemeColors._(brightness, variant);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: variant.primary,
      brightness: brightness,
      surface: isDark ? variant.cardBgDark : null,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.scaffoldBg,
      colorScheme: colorScheme,
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[colors],

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
        backgroundColor: isDark ? variant.cardBgDark : Colors.black87,
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
        selectedColor: variant.primary.withValues(alpha: isDark ? 0.3 : 0.15),
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? variant.cardBgDark : Colors.white,
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
          borderSide: BorderSide(color: variant.primary, width: 2),
        ),
      ),

      // Misc
      cardColor: colors.cardBg,
      dividerColor: colors.divider,
    );
  }
}

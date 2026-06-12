// lib/theme/theme_variant.dart
// Variantes de thème — sélectionnables par les utilisateurs Premium.
// Le thème "sage" est le défaut gratuit, conserve l'identité de la marque.

import 'package:flutter/material.dart';

class ThemeVariantPalette {
  final String id;
  final String name;
  final String description;
  final Color primary;
  final Color primaryDeep;
  final Color accent;
  final bool isPremium;

  // Surfaces light mode (un thème = sa propre ambiance)
  final Color scaffoldBgLight;
  final Color cardBgLight;
  final Color libraryBgLight;
  final Color pillBgLight;
  final Color accentBgLight;

  // Surfaces dark mode (tintées subtilement vers le primary)
  final Color scaffoldBgDark;
  final Color cardBgDark;
  final Color libraryBgDark;
  final Color pillBgDark;
  final Color accentBgDark;

  const ThemeVariantPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.primaryDeep,
    required this.accent,
    required this.isPremium,
    required this.scaffoldBgLight,
    required this.cardBgLight,
    required this.libraryBgLight,
    required this.pillBgLight,
    required this.accentBgLight,
    required this.scaffoldBgDark,
    required this.cardBgDark,
    required this.libraryBgDark,
    required this.pillBgDark,
    required this.accentBgDark,
  });
}

class ThemeVariants {
  static const sage = ThemeVariantPalette(
    id: 'sage',
    name: 'Sage',
    description: 'Lecture cosy, défaut LexDay',
    primary: Color(0xFF6B988D),
    primaryDeep: Color(0xFF466B62),
    accent: Color(0xFFC6A85A),
    isPremium: false,
    scaffoldBgLight: Color(0xFFF6F1EC),
    cardBgLight: Color(0xFFFFFFFF),
    libraryBgLight: Color(0xFFFAF3E8),
    pillBgLight: Color(0xFFF0EBE1),
    accentBgLight: Color(0xFFE8FFFA),
    scaffoldBgDark: Color(0xFF121212),
    cardBgDark: Color(0xFF1E1E1E),
    libraryBgDark: Color(0xFF1A1814),
    pillBgDark: Color(0xFF2A2520),
    accentBgDark: Color(0xFF1A4D44),
  );

  static const ink = ThemeVariantPalette(
    id: 'ink',
    name: 'Encre',
    description: 'Bibliothèque classique',
    primary: Color(0xFF2A3A5A),
    primaryDeep: Color(0xFF1A2B45),
    accent: Color(0xFFD4A54A),
    isPremium: true,
    scaffoldBgLight: Color(0xFFEDE9E1),
    cardBgLight: Color(0xFFF7F4ED),
    libraryBgLight: Color(0xFFE5E1D8),
    pillBgLight: Color(0xFFDDD8CC),
    accentBgLight: Color(0xFFE0E5F0),
    scaffoldBgDark: Color(0xFF101319),
    cardBgDark: Color(0xFF1B1F28),
    libraryBgDark: Color(0xFF14171E),
    pillBgDark: Color(0xFF252A35),
    accentBgDark: Color(0xFF1F2D4A),
  );

  static const terra = ThemeVariantPalette(
    id: 'terra',
    name: 'Terra',
    description: 'Lecture café, automnal',
    primary: Color(0xFFA0593E),
    primaryDeep: Color(0xFF6E3A28),
    accent: Color(0xFFD6B27D),
    isPremium: true,
    scaffoldBgLight: Color(0xFFF3EAE0),
    cardBgLight: Color(0xFFFBF6F0),
    libraryBgLight: Color(0xFFEDE2D4),
    pillBgLight: Color(0xFFE6DACA),
    accentBgLight: Color(0xFFF5EBE0),
    scaffoldBgDark: Color(0xFF1A1310),
    cardBgDark: Color(0xFF241B17),
    libraryBgDark: Color(0xFF1F1814),
    pillBgDark: Color(0xFF2E231D),
    accentBgDark: Color(0xFF3F2418),
  );

  static const lavender = ThemeVariantPalette(
    id: 'lavender',
    name: 'Lavande',
    description: 'Doux, romanesque',
    primary: Color(0xFF7A6F9E),
    primaryDeep: Color(0xFF514764),
    accent: Color(0xFFC9A8C7),
    isPremium: true,
    scaffoldBgLight: Color(0xFFEEEAF4),
    cardBgLight: Color(0xFFF8F5FC),
    libraryBgLight: Color(0xFFE6E1EC),
    pillBgLight: Color(0xFFDFD9E7),
    accentBgLight: Color(0xFFF0E5F4),
    scaffoldBgDark: Color(0xFF14111A),
    cardBgDark: Color(0xFF1F1B28),
    libraryBgDark: Color(0xFF181420),
    pillBgDark: Color(0xFF2A2535),
    accentBgDark: Color(0xFF2D2240),
  );

  static const forest = ThemeVariantPalette(
    id: 'forest',
    name: 'Forêt',
    description: 'Nature, contemplatif',
    primary: Color(0xFF3F5E4F),
    primaryDeep: Color(0xFF273A31),
    accent: Color(0xFFA0875E),
    isPremium: true,
    scaffoldBgLight: Color(0xFFEAF0EB),
    cardBgLight: Color(0xFFF5F9F6),
    libraryBgLight: Color(0xFFE1E9E2),
    pillBgLight: Color(0xFFD7E0D8),
    accentBgLight: Color(0xFFDFEEE1),
    scaffoldBgDark: Color(0xFF101510),
    cardBgDark: Color(0xFF1A2018),
    libraryBgDark: Color(0xFF141A14),
    pillBgDark: Color(0xFF222B22),
    accentBgDark: Color(0xFF1F3329),
  );

  static const dawn = ThemeVariantPalette(
    id: 'dawn',
    name: 'Aube',
    description: 'Vibrant, moderne',
    primary: Color(0xFFD17B5E),
    primaryDeep: Color(0xFF9F5A40),
    accent: Color(0xFF5E7A8A),
    isPremium: true,
    scaffoldBgLight: Color(0xFFF5ECE6),
    cardBgLight: Color(0xFFFDF7F3),
    libraryBgLight: Color(0xFFEFE3DC),
    pillBgLight: Color(0xFFE7DACE),
    accentBgLight: Color(0xFFF7ECE5),
    scaffoldBgDark: Color(0xFF1A1310),
    cardBgDark: Color(0xFF241B17),
    libraryBgDark: Color(0xFF1F1814),
    pillBgDark: Color(0xFF2E231D),
    accentBgDark: Color(0xFF4A271C),
  );

  static const all = <ThemeVariantPalette>[
    sage,
    ink,
    terra,
    lavender,
    forest,
    dawn,
  ];

  static ThemeVariantPalette fromId(String? id) {
    return all.firstWhere(
      (v) => v.id == id,
      orElse: () => sage,
    );
  }
}

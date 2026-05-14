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

  const ThemeVariantPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.primaryDeep,
    required this.accent,
    required this.isPremium,
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
  );

  static const ink = ThemeVariantPalette(
    id: 'ink',
    name: 'Encre',
    description: 'Bibliothèque classique',
    primary: Color(0xFF2A3A5A),
    primaryDeep: Color(0xFF1A2B45),
    accent: Color(0xFFD4A54A),
    isPremium: true,
  );

  static const terra = ThemeVariantPalette(
    id: 'terra',
    name: 'Terra',
    description: 'Lecture café, automnal',
    primary: Color(0xFFA0593E),
    primaryDeep: Color(0xFF6E3A28),
    accent: Color(0xFFD6B27D),
    isPremium: true,
  );

  static const lavender = ThemeVariantPalette(
    id: 'lavender',
    name: 'Lavande',
    description: 'Doux, romanesque',
    primary: Color(0xFF7A6F9E),
    primaryDeep: Color(0xFF514764),
    accent: Color(0xFFC9A8C7),
    isPremium: true,
  );

  static const forest = ThemeVariantPalette(
    id: 'forest',
    name: 'Forêt',
    description: 'Nature, contemplatif',
    primary: Color(0xFF3F5E4F),
    primaryDeep: Color(0xFF273A31),
    accent: Color(0xFFA0875E),
    isPremium: true,
  );

  static const dawn = ThemeVariantPalette(
    id: 'dawn',
    name: 'Aube',
    description: 'Vibrant, moderne',
    primary: Color(0xFFD17B5E),
    primaryDeep: Color(0xFF9F5A40),
    accent: Color(0xFF5E7A8A),
    isPremium: true,
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

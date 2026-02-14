import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Icônes disponibles pour les listes personnalisées
const Map<String, IconData> kIconOptions = {
  'book-open': LucideIcons.bookOpen,
  'heart': LucideIcons.heart,
  'star': LucideIcons.star,
  'bookmark': LucideIcons.bookmark,
  'flame': LucideIcons.flame,
  'sun': LucideIcons.sun,
  'moon': LucideIcons.moon,
  'coffee': LucideIcons.coffee,
  'pen-tool': LucideIcons.penTool,
  'feather': LucideIcons.feather,
  'globe-2': LucideIcons.globe2,
  'compass': LucideIcons.compass,
  'rocket': LucideIcons.rocket,
  'brain': LucideIcons.brain,
  'lightbulb': LucideIcons.lightbulb,
  'music': LucideIcons.music,
  'palette': LucideIcons.palette,
  'gem': LucideIcons.gem,
  'zap': LucideIcons.zap,
  'crown': LucideIcons.crown,
  'trophy': LucideIcons.trophy,
  'target': LucideIcons.target,
  'landmark': LucideIcons.landmark,
  'search': LucideIcons.search,
};

/// Couleurs disponibles pour les listes personnalisées
const List<String> kListColorOptions = [
  '#7FA497', // vert (primary)
  '#FF6B35', // orange
  '#4A2D8B', // violet
  '#DC3545', // rouge
  '#4A90D9', // bleu
  '#D4A853', // doré
  '#2D6A4F', // vert forêt
  '#AB47BC', // mauve
  '#26A69A', // teal
  '#E91E63', // rose
];

/// Convertit un nom d'icône en IconData
IconData mapLucideIconName(String name) {
  return kIconOptions[name] ?? LucideIcons.bookOpen;
}

/// Convertit un hex en Color
Color hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// Génère 3 couleurs de gradient depuis une couleur de base hex
List<Color> generateGradientFromHex(String hex) {
  final base = HSLColor.fromColor(hexToColor(hex));

  final light = base
      .withSaturation((base.saturation - 0.15).clamp(0.0, 1.0))
      .withLightness((base.lightness + 0.25).clamp(0.0, 0.95))
      .toColor();

  final mid = base.toColor();

  final dark = base
      .withSaturation((base.saturation + 0.1).clamp(0.0, 1.0))
      .withLightness((base.lightness - 0.15).clamp(0.05, 1.0))
      .toColor();

  return [light, mid, dark];
}

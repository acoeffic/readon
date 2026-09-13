import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../data/icon_options.dart';

class CuratedBookEntry {
  final String isbn;
  final String title;
  final String author;

  const CuratedBookEntry({
    required this.isbn,
    required this.title,
    required this.author,
  });

  factory CuratedBookEntry.fromJson(Map<String, dynamic> json) {
    return CuratedBookEntry(
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
    );
  }
}

/// Icônes utilisables par les listes curatées (colonne `icon` de la table
/// Supabase `curated_lists`, noms lucide en kebab-case).
/// Étend le set des listes personnalisées (`kIconOptions`).
/// ⚠️ Un nom absent de cette map retombe sur book-open : ajouter l'entrée ici
/// (et rebuilder) avant d'utiliser une nouvelle icône en base.
const Map<String, IconData> kCuratedListIcons = {
  ...kIconOptions,
  'cloud-rain': LucideIcons.cloudRain,
  'heart-crack': LucideIcons.heartCrack,
  'laugh': LucideIcons.laugh,
  'palmtree': LucideIcons.palmtree,
  'award': LucideIcons.award,
  'atom': LucideIcons.atom,
  'globe': LucideIcons.globe,
  'calendar': LucideIcons.calendar,
};

class CuratedList {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<CuratedBookEntry> books;

  const CuratedList({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.books,
  });

  /// Construit une liste depuis une row Supabase `curated_lists` avec ses
  /// livres embarqués (`curated_list_books(isbn, title, author, position)`).
  factory CuratedList.fromJson(Map<String, dynamic> json) {
    final booksRaw = (json['curated_list_books'] as List<dynamic>? ?? [])
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList()
      ..sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
          .compareTo((b['position'] as num?)?.toInt() ?? 0));

    return CuratedList(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: kCuratedListIcons[json['icon']] ?? LucideIcons.bookOpen,
      gradientColors: _gradientFromJson(json['gradient_colors']),
      books: booksRaw.map(CuratedBookEntry.fromJson).toList(),
    );
  }

  static List<Color> _gradientFromJson(dynamic raw) {
    final colors = (raw as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((h) => RegExp(r'^#?[0-9a-fA-F]{6,8}$').hasMatch(h))
        .map(hexToColor)
        .toList();
    if (colors.isEmpty) {
      return const [Color(0xFFD0DEF0), Color(0xFF8AACC8), Color(0xFF6B8EAD)];
    }
    if (colors.length == 1) return [colors.first, colors.first];
    return colors;
  }

  int get bookCount => books.length;
}

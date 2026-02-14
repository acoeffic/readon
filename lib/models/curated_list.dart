import 'package:flutter/material.dart';

class CuratedBookEntry {
  final String isbn;
  final String title;
  final String author;

  const CuratedBookEntry({
    required this.isbn,
    required this.title,
    required this.author,
  });
}

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

  int get bookCount => books.length;
}

// lib/features/badges/models/anniversary_badge.dart

import 'package:flutter/material.dart';

class AnniversaryBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int years;
  final Color primaryColor;
  final Color secondaryColor;
  final Color ringColor;
  final bool isPremium;

  const AnniversaryBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.years,
    required this.primaryColor,
    required this.secondaryColor,
    required this.ringColor,
    required this.isPremium,
  });

  String get yearLabel => years == 1 ? 'AN' : 'ANS';

  static const List<AnniversaryBadge> all = [
    AnniversaryBadge(
      id: 'anniversary_1',
      name: 'Première Bougie 🌱',
      description:
          'Tu as planté la graine. Un an de lectures partagées, de sessions inspirantes et de découvertes.',
      icon: '🌱',
      years: 1,
      primaryColor: Color(0xFF6B988D),
      secondaryColor: Color(0xFFA8C5B8),
      ringColor: Color(0xFF5A8377),
      isPremium: false,
    ),
    AnniversaryBadge(
      id: 'anniversary_2',
      name: 'Lecteur Fidèle 📖',
      description:
          'Deux ans déjà ! Ta passion pour la lecture ne faiblit pas. Tu fais partie des piliers de la communauté.',
      icon: '📖',
      years: 2,
      primaryColor: Color(0xFFC4956A),
      secondaryColor: Color(0xFFE0C4A8),
      ringColor: Color(0xFFB07E52),
      isPremium: false,
    ),
    AnniversaryBadge(
      id: 'anniversary_3',
      name: 'Sage des Pages 🦉',
      description:
          'Trois ans de sagesse littéraire. Ton parcours inspire les nouveaux lecteurs qui rejoignent l\'aventure.',
      icon: '🦉',
      years: 3,
      primaryColor: Color(0xFF8B7355),
      secondaryColor: Color(0xFFC4AD8F),
      ringColor: Color(0xFF74603F),
      isPremium: false,
    ),
    AnniversaryBadge(
      id: 'anniversary_4',
      name: 'Étoile Littéraire ✨',
      description:
          'Quatre ans d\'étoiles dans les yeux. Ta constance est remarquable, tu brilles dans la galaxie LexDay.',
      icon: '✨',
      years: 4,
      primaryColor: Color(0xFF7A6FA0),
      secondaryColor: Color(0xFFB5AED0),
      ringColor: Color(0xFF655690),
      isPremium: true,
    ),
    AnniversaryBadge(
      id: 'anniversary_5',
      name: 'Légende Vivante 👑',
      description:
          'Cinq ans. Tu es une légende. Les livres t\'ont transformé et tu as transformé cette communauté.',
      icon: '👑',
      years: 5,
      primaryColor: Color(0xFFC49A2A),
      secondaryColor: Color(0xFFE8D48B),
      ringColor: Color(0xFFA67F1A),
      isPremium: true,
    ),
  ];

  static AnniversaryBadge? getById(String id) {
    for (final badge in all) {
      if (badge.id == id) return badge;
    }
    return null;
  }

  static AnniversaryBadge? getByYears(int years) {
    for (final badge in all) {
      if (badge.years == years) return badge;
    }
    return null;
  }
}

class AnniversaryStats {
  final int booksFinished;
  final int hoursRead;
  final int bestFlow;
  final int commentsCount;

  const AnniversaryStats({
    required this.booksFinished,
    required this.hoursRead,
    required this.bestFlow,
    required this.commentsCount,
  });

  static const empty = AnniversaryStats(
    booksFinished: 0,
    hoursRead: 0,
    bestFlow: 0,
    commentsCount: 0,
  );
}

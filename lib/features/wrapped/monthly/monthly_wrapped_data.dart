import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Month themes – one per month, inspired by the React mockup
// ---------------------------------------------------------------------------

class MonthTheme {
  final List<Color> gradientColors;
  final Color accent;
  final String emoji;

  const MonthTheme({
    required this.gradientColors,
    required this.accent,
    required this.emoji,
  });
}

const monthThemes = <int, MonthTheme>{
  1: MonthTheme(
    gradientColors: [Color(0xFF0B1120), Color(0xFF1B2A4A)],
    accent: Color(0xFF7EC8E3),
    emoji: '\u2744\uFE0F', // snowflake
  ),
  2: MonthTheme(
    gradientColors: [Color(0xFF1A0A2E), Color(0xFF3D1F56)],
    accent: Color(0xFFE8A0BF),
    emoji: '\uD83D\uDC9C', // purple heart
  ),
  3: MonthTheme(
    gradientColors: [Color(0xFF0A1F0A), Color(0xFF1B3D2F)],
    accent: Color(0xFF90EE90),
    emoji: '\uD83C\uDF31', // seedling
  ),
  4: MonthTheme(
    gradientColors: [Color(0xFF1F1A0A), Color(0xFF3D3520)],
    accent: Color(0xFFFFD700),
    emoji: '\uD83C\uDF24\uFE0F', // sun behind cloud
  ),
  5: MonthTheme(
    gradientColors: [Color(0xFF0A1A1F), Color(0xFF1B3540)],
    accent: Color(0xFFFF6B8A),
    emoji: '\uD83C\uDF38', // cherry blossom
  ),
  6: MonthTheme(
    gradientColors: [Color(0xFF1F0F00), Color(0xFF4A2800)],
    accent: Color(0xFFFFA24C),
    emoji: '\u2600\uFE0F', // sun
  ),
  7: MonthTheme(
    gradientColors: [Color(0xFF00101F), Color(0xFF002040)],
    accent: Color(0xFF00D4FF),
    emoji: '\uD83C\uDFD6\uFE0F', // beach
  ),
  8: MonthTheme(
    gradientColors: [Color(0xFF1A0F00), Color(0xFF3D2400)],
    accent: Color(0xFFFFB347),
    emoji: '\uD83C\uDF05', // sunrise
  ),
  9: MonthTheme(
    gradientColors: [Color(0xFF150A00), Color(0xFF3A2010)],
    accent: Color(0xFFD4915E),
    emoji: '\uD83C\uDF42', // fallen leaf
  ),
  10: MonthTheme(
    gradientColors: [Color(0xFF0F0A1A), Color(0xFF2A1F3D)],
    accent: Color(0xFFC77DFF),
    emoji: '\uD83C\uDF83', // jack-o-lantern
  ),
  11: MonthTheme(
    gradientColors: [Color(0xFF0D0D0D), Color(0xFF2A2A2A)],
    accent: Color(0xFFA0A0A0),
    emoji: '\uD83C\uDF2B\uFE0F', // fog
  ),
  12: MonthTheme(
    gradientColors: [Color(0xFF0A0015), Color(0xFF1A0A3D)],
    accent: Color(0xFFFFD93D),
    emoji: '\u2728', // sparkles
  ),
};

MonthTheme getMonthTheme(int month) =>
    monthThemes[month] ?? monthThemes[1]!;

// French month names
const _monthNames = [
  '', // index 0 unused
  'Janvier', 'Fevrier', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Aout', 'Septembre', 'Octobre', 'Novembre', 'Decembre',
];

String getMonthName(int month) =>
    (month >= 1 && month <= 12) ? _monthNames[month] : '';

// French day-of-week names (1 = Monday in DateTime.weekday)
const _dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

String getDayName(int weekday) =>
    (weekday >= 1 && weekday <= 7) ? _dayNames[weekday - 1] : '';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class TopBookData {
  final String title;
  final String author;
  final int totalMinutes;
  final String? coverUrl;

  const TopBookData({
    required this.title,
    required this.author,
    required this.totalMinutes,
    this.coverUrl,
  });

  /// Formatted reading time, e.g. "8h30"
  String get formattedTime {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}

class BadgeData {
  final String icon;
  final String name;

  const BadgeData({required this.icon, required this.name});

  String get display => '$icon $name';
}

class MonthlyWrappedData {
  final int month; // 1-12
  final int year;
  final int totalMinutes;
  final int sessions;
  final int avgSessionMinutes;
  final int booksFinished;
  final int booksInProgress;
  final int longestSessionMinutes;
  final int bestDayWeekday; // 1=Mon..7=Sun
  final int longestFlow;
  final int currentFlow;
  final TopBookData? topBook;
  final int vsLastMonthPercent; // can be negative
  final List<int> dailyMinutes; // one entry per day of the month
  final List<BadgeData> badges;

  const MonthlyWrappedData({
    required this.month,
    required this.year,
    required this.totalMinutes,
    required this.sessions,
    required this.avgSessionMinutes,
    required this.booksFinished,
    required this.booksInProgress,
    required this.longestSessionMinutes,
    required this.bestDayWeekday,
    required this.longestFlow,
    required this.currentFlow,
    this.topBook,
    required this.vsLastMonthPercent,
    required this.dailyMinutes,
    required this.badges,
  });

  String get monthName => getMonthName(month);
  MonthTheme get theme => getMonthTheme(month);
  String get bestDayName => getDayName(bestDayWeekday);

  String get formattedTotalTime {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get formattedLongestSession {
    final h = longestSessionMinutes ~/ 60;
    final m = longestSessionMinutes % 60;
    if (h == 0) return '${m}min';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get previousMonthName => getMonthName(month == 1 ? 12 : month - 1);

  // Demo data for previewing
  static MonthlyWrappedData demo() {
    return MonthlyWrappedData(
      month: 10,
      year: 2025,
      totalMinutes: 1840,
      sessions: 42,
      avgSessionMinutes: 44,
      booksFinished: 3,
      booksInProgress: 2,
      longestSessionMinutes: 138,
      bestDayWeekday: 7,
      longestFlow: 12,
      currentFlow: 5,
      topBook: TopBookData(
        title: 'Projet Hail Mary',
        author: 'Andy Weir',
        totalMinutes: 510,
        coverUrl: 'https://books.google.com/books/content?id=sOaBEAAAQBAJ&printsec=frontcover&img=1&zoom=1',
      ),
      vsLastMonthPercent: 18,
      dailyMinutes: [
        30, 0, 45, 50, 0, 0, 60, 35, 42, 0, 0, 55, 48, 70, 0, 20,
        0, 65, 40, 0, 80, 55, 0, 0, 45, 60, 38, 0, 50, 72, 0,
      ],
      badges: [
        BadgeData(icon: '\uD83E\uDD89', name: 'Night Owl'),
        BadgeData(icon: '\uD83D\uDCD6', name: 'Marathon'),
      ],
    );
  }
}

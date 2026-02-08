// Data models for the Yearly Wrapped feature.

class GenreData {
  final String name;
  final int totalMinutes;
  final double percentage;

  const GenreData({
    required this.name,
    required this.totalMinutes,
    required this.percentage,
  });

  String get formattedHours {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}

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

  String get formattedTime {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}

class MilestoneData {
  final String icon;
  final String title;
  final String? dateLabel; // "5 Mars", "Juin", "22 Sept"

  const MilestoneData({
    required this.icon,
    required this.title,
    this.dateLabel,
  });
}

class MonthlyBookCount {
  final String label; // "Jan", "Fév", etc.
  final int count;

  const MonthlyBookCount({required this.label, required this.count});
}

class YearlyWrappedData {
  final int year;
  final String? userName;

  // Slide 1 – Time
  final int totalMinutes;
  final int totalSessions;
  final int avgSessionMinutes;

  // Slide 2 – Books
  final int booksFinished;
  final List<MonthlyBookCount> booksPerMonth;

  // Slide 3 – Genres
  final List<GenreData> topGenres;

  // Slide 4 – Habits / reader profile
  final String readerType; // "Night Owl Reader"
  final String readerEmoji; // 🌙
  final int nightSessionsPercent;
  final String peakHour; // "22h30"
  final int activeDays;
  final int bestFlow;
  final String bestFlowPeriod; // "Du 5 au 28 mars"
  final int longestSessionMinutes;
  final String longestSessionDateLabel; // "14 juillet"

  // Slide 5 – Top 5 books
  final List<TopBookData> topBooks;

  // Slide 6 – Milestones
  final List<MilestoneData> milestones;

  // Slide 7 – Social ranking
  final int percentileRank;
  final int totalUsersCompared;

  // Slide 8 – Evolution
  final int previousYearMinutes;
  final int previousYearBooks;
  final int previousYearSessions;
  final int previousYearFlow;

  const YearlyWrappedData({
    required this.year,
    this.userName,
    required this.totalMinutes,
    required this.totalSessions,
    required this.avgSessionMinutes,
    required this.booksFinished,
    required this.booksPerMonth,
    required this.topGenres,
    required this.readerType,
    required this.readerEmoji,
    required this.nightSessionsPercent,
    required this.peakHour,
    required this.activeDays,
    required this.bestFlow,
    required this.bestFlowPeriod,
    required this.longestSessionMinutes,
    required this.longestSessionDateLabel,
    required this.topBooks,
    required this.milestones,
    required this.percentileRank,
    required this.totalUsersCompared,
    required this.previousYearMinutes,
    required this.previousYearBooks,
    required this.previousYearSessions,
    required this.previousYearFlow,
  });

  int get totalHours => totalMinutes ~/ 60;

  String get formattedTotalTime {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get formattedPreviousYearTime {
    final h = previousYearMinutes ~/ 60;
    final m = previousYearMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get formattedLongestSession {
    final h = longestSessionMinutes ~/ 60;
    final m = longestSessionMinutes % 60;
    if (h == 0) return '${m}min';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get totalTimeHumanized {
    final days = totalMinutes ~/ (60 * 24);
    final hours = (totalMinutes % (60 * 24)) ~/ 60;
    if (days == 0) return 'Soit $hours heures de lecture pure';
    return 'Soit $days jours et $hours heures de lecture pure';
  }

  bool get hasPreviousYear => previousYearMinutes > 0;

  int get evolutionPercent {
    if (previousYearMinutes == 0) return totalMinutes > 0 ? 100 : 0;
    return (((totalMinutes - previousYearMinutes) / previousYearMinutes) * 100)
        .round();
  }

  int get evolutionBooksPercent {
    if (previousYearBooks == 0) return booksFinished > 0 ? 100 : 0;
    return (((booksFinished - previousYearBooks) / previousYearBooks) * 100)
        .round();
  }

  int get evolutionSessionsPercent {
    if (previousYearSessions == 0) return totalSessions > 0 ? 100 : 0;
    return (((totalSessions - previousYearSessions) / previousYearSessions) *
            100)
        .round();
  }

  int get evolutionFlowPercent {
    if (previousYearFlow == 0) return bestFlow > 0 ? 100 : 0;
    return (((bestFlow - previousYearFlow) / previousYearFlow) * 100)
        .round();
  }

  static YearlyWrappedData demo() {
    return YearlyWrappedData(
      year: 2025,
      userName: 'Adrien',
      totalMinutes: 14820,
      totalSessions: 1482,
      avgSessionMinutes: 41,
      booksFinished: 34,
      booksPerMonth: const [
        MonthlyBookCount(label: 'Jan', count: 2),
        MonthlyBookCount(label: 'Fev', count: 3),
        MonthlyBookCount(label: 'Mar', count: 4),
        MonthlyBookCount(label: 'Avr', count: 2),
        MonthlyBookCount(label: 'Mai', count: 3),
        MonthlyBookCount(label: 'Jun', count: 5),
        MonthlyBookCount(label: 'Jul', count: 4),
        MonthlyBookCount(label: 'Aou', count: 3),
        MonthlyBookCount(label: 'Sep', count: 2),
        MonthlyBookCount(label: 'Oct', count: 3),
        MonthlyBookCount(label: 'Nov', count: 2),
        MonthlyBookCount(label: 'Dec', count: 1),
      ],
      topGenres: const [
        GenreData(name: 'Science-Fiction', totalMinutes: 5160, percentage: 35),
        GenreData(
            name: 'Developpement personnel',
            totalMinutes: 3540,
            percentage: 24),
        GenreData(name: 'Thriller', totalMinutes: 2640, percentage: 18),
        GenreData(name: 'Fantasy', totalMinutes: 2100, percentage: 14),
        GenreData(name: 'Biographies', totalMinutes: 1380, percentage: 9),
      ],
      readerType: 'Night Owl Reader',
      readerEmoji: '\uD83C\uDF19',
      nightSessionsPercent: 68,
      peakHour: '22h30',
      activeDays: 186,
      bestFlow: 23,
      bestFlowPeriod: 'Du 5 au 28 mars',
      longestSessionMinutes: 192,
      longestSessionDateLabel: '14 juillet',
      topBooks: const [
        TopBookData(
            title: 'Dune', author: 'Frank Herbert', totalMinutes: 1110),
        TopBookData(
            title: 'Atomic Habits', author: 'James Clear', totalMinutes: 735),
        TopBookData(
            title: 'Projet Hail Mary', author: 'Andy Weir', totalMinutes: 700),
        TopBookData(
            title: "L'Etranger", author: 'Albert Camus', totalMinutes: 380),
        TopBookData(
            title: 'Neuromancien',
            author: 'William Gibson',
            totalMinutes: 355),
      ],
      milestones: const [
        MilestoneData(
            icon: '\uD83D\uDD25',
            title: 'Flow de 23 jours consecutifs',
            dateLabel: '5 Mars'),
        MilestoneData(
            icon: '\u26A1',
            title: 'Session marathon de 3h12',
            dateLabel: '14 Juillet'),
        MilestoneData(
            icon: '\uD83D\uDCDA',
            title: 'Mois le plus productif — 5 livres',
            dateLabel: 'Juin'),
        MilestoneData(
            icon: '\uD83C\uDFC5',
            title: 'Badge legendaire debloque',
            dateLabel: '22 Sept'),
        MilestoneData(
            icon: '\uD83C\uDF19',
            title: '100eme session de nuit',
            dateLabel: 'Octobre'),
      ],
      percentileRank: 8,
      totalUsersCompared: 12400,
      previousYearMinutes: 8880,
      previousYearBooks: 21,
      previousYearSessions: 890,
      previousYearFlow: 14,
    );
  }
}

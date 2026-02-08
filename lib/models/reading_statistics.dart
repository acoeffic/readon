import '../services/badges_service.dart';
import 'reading_goal.dart';

class MonthlyPageCount {
  final String label;
  final int month;
  final int pages;

  const MonthlyPageCount({
    required this.label,
    required this.month,
    required this.pages,
  });
}

class PersonalRecords {
  final int longestSessionMinutes;
  final DateTime? longestSessionDate;
  final int bestFlow;
  final int totalPagesAllTime;
  final int totalSessionsAllTime;
  final int totalBooksFinished;
  final int totalMinutesAllTime;

  const PersonalRecords({
    required this.longestSessionMinutes,
    this.longestSessionDate,
    required this.bestFlow,
    required this.totalPagesAllTime,
    required this.totalSessionsAllTime,
    required this.totalBooksFinished,
    required this.totalMinutesAllTime,
  });

  String get formattedLongestSession {
    if (longestSessionMinutes < 60) return '${longestSessionMinutes}min';
    final h = longestSessionMinutes ~/ 60;
    final m = longestSessionMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m}min';
  }

  String get formattedTotalTime {
    final h = totalMinutesAllTime ~/ 60;
    return '${h}h';
  }
}

class GenreStatData {
  final String name;
  final int totalMinutes;
  final double percentage;

  const GenreStatData({
    required this.name,
    required this.totalMinutes,
    required this.percentage,
  });
}

class ReadingStatistics {
  final List<ReadingGoal> activeGoals;
  final List<MonthlyPageCount> pagesPerMonth;
  final List<GenreStatData> genreDistribution;
  final Map<int, Map<int, int>> readingHeatmap; // weekday -> {timeSlot -> count}
  final PersonalRecords records;
  final int unlockedBadges;
  final int totalBadges;
  final List<UserBadge> recentBadges;

  const ReadingStatistics({
    required this.activeGoals,
    required this.pagesPerMonth,
    required this.genreDistribution,
    required this.readingHeatmap,
    required this.records,
    required this.unlockedBadges,
    required this.totalBadges,
    required this.recentBadges,
  });
}

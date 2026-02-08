import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_statistics.dart';
import '../models/reading_goal.dart';
import 'badges_service.dart';
import 'goals_service.dart';
import 'flow_service.dart';

const _frenchMonths = [
  '', 'Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun',
  'Jul', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec',
];

class StatisticsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoalsService _goalsService = GoalsService();
  final BadgesService _badgesService = BadgesService();
  final FlowService _flowService = FlowService();

  Future<ReadingStatistics> getStatistics({int? year}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecte');

    final targetYear = year ?? DateTime.now().year;
    final startIso = DateTime.utc(targetYear).toIso8601String();
    final endIso = DateTime.utc(targetYear + 1).toIso8601String();

    final results = await Future.wait([
      _goalsService.getActiveGoalsWithProgress(year: targetYear), // 0
      _getCompletedSessions(userId, startIso, endIso),            // 1
      _badgesService.getUserBadges(),                              // 2
      _flowService.getUserFlow(),                              // 3
      _getAllTimeTotals(userId),                                    // 4
    ]);

    final goals = results[0] as List<ReadingGoal>;
    final sessions = results[1] as List<Map<String, dynamic>>;
    final badges = results[2] as List<UserBadge>;
    final flow = results[3] as dynamic;
    final allTimeTotals = results[4] as Map<String, int>;

    // Aggregate session data
    final Map<int, int> monthlyPages = {};
    final Map<String, int> genreMinutes = {};
    final Map<int, Map<int, int>> heatmap = {};
    int longestSessionMin = 0;
    DateTime? longestSessionDate;

    for (final s in sessions) {
      final startTime = DateTime.parse(s['start_time'] as String).toLocal();
      final endTime = DateTime.parse(s['end_time'] as String).toLocal();
      final durationMin = endTime.difference(startTime).inMinutes;
      if (durationMin <= 0) continue;

      final startPage = (s['start_page'] as num?)?.toInt() ?? 0;
      final endPage = (s['end_page'] as num?)?.toInt() ?? 0;
      final pagesRead = endPage > startPage ? endPage - startPage : 0;

      // Pages per month
      monthlyPages[startTime.month] =
          (monthlyPages[startTime.month] ?? 0) + pagesRead;

      // Genre distribution
      final genre =
          (s['books'] as Map?)?['genre'] as String? ?? 'Autre';
      genreMinutes[genre] = (genreMinutes[genre] ?? 0) + durationMin;

      // Heatmap: weekday (1=Mon..7=Sun) x timeSlot (0=Matin, 1=Midi, 2=Soir, 3=Nuit)
      final weekday = startTime.weekday;
      final hour = startTime.hour;
      final int timeSlot;
      if (hour >= 6 && hour < 12) {
        timeSlot = 0; // Matin
      } else if (hour >= 12 && hour < 17) {
        timeSlot = 1; // Midi
      } else if (hour >= 17 && hour < 22) {
        timeSlot = 2; // Soir
      } else {
        timeSlot = 3; // Nuit (22-5h)
      }
      heatmap.putIfAbsent(weekday, () => {});
      heatmap[weekday]![timeSlot] =
          (heatmap[weekday]![timeSlot] ?? 0) + 1;

      // Longest session
      if (durationMin > longestSessionMin) {
        longestSessionMin = durationMin;
        longestSessionDate = startTime;
      }
    }

    // Build pages per month
    final pagesPerMonth = <MonthlyPageCount>[];
    for (int m = 1; m <= 12; m++) {
      pagesPerMonth.add(MonthlyPageCount(
        label: _frenchMonths[m],
        month: m,
        pages: monthlyPages[m] ?? 0,
      ));
    }

    // Build genre distribution
    int totalGenreMinutes = genreMinutes.values.fold(0, (a, b) => a + b);
    final sortedGenres = genreMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final genreDistribution = sortedGenres.take(6).map((e) {
      final pct = totalGenreMinutes > 0
          ? (e.value / totalGenreMinutes * 100)
          : 0.0;
      return GenreStatData(
        name: e.key,
        totalMinutes: e.value,
        percentage: double.parse(pct.toStringAsFixed(1)),
      );
    }).toList();

    // Badges
    final unlockedBadges = badges.where((b) => b.isUnlocked).toList();
    final recentUnlocked = unlockedBadges
      ..sort((a, b) => (b.unlockedAt ?? DateTime(2000))
          .compareTo(a.unlockedAt ?? DateTime(2000)));

    // Personal records
    final records = PersonalRecords(
      longestSessionMinutes: longestSessionMin,
      longestSessionDate: longestSessionDate,
      bestFlow: flow.longestFlow as int,
      totalPagesAllTime: allTimeTotals['pages'] ?? 0,
      totalSessionsAllTime: allTimeTotals['sessions'] ?? 0,
      totalBooksFinished: allTimeTotals['books'] ?? 0,
      totalMinutesAllTime: allTimeTotals['minutes'] ?? 0,
    );

    return ReadingStatistics(
      activeGoals: goals,
      pagesPerMonth: pagesPerMonth,
      genreDistribution: genreDistribution,
      readingHeatmap: heatmap,
      records: records,
      unlockedBadges: unlockedBadges.length,
      totalBadges: badges.length,
      recentBadges: recentUnlocked.take(3).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _getCompletedSessions(
    String userId,
    String startIso,
    String endIso,
  ) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select(
              'start_time, end_time, start_page, end_page, book_id, books(title, author, cover_url, genre)')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', startIso)
          .lt('start_time', endIso)
          .order('start_time');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Erreur _getCompletedSessions: $e');
      return [];
    }
  }

  Future<Map<String, int>> _getAllTimeTotals(String userId) async {
    try {
      final results = await Future.wait([
        _supabase
            .from('reading_sessions')
            .select('start_time, end_time, start_page, end_page')
            .eq('user_id', userId)
            .not('end_time', 'is', null),
        _supabase
            .from('user_books')
            .select('book_id')
            .eq('user_id', userId)
            .eq('status', 'finished'),
      ]);

      final allSessions = results[0] as List;
      final finishedBooks = results[1] as List;

      int totalMinutes = 0;
      int totalPages = 0;

      for (final s in allSessions) {
        final st = DateTime.parse(s['start_time'] as String);
        final et = DateTime.parse(s['end_time'] as String);
        totalMinutes += et.difference(st).inMinutes;

        final startPage = (s['start_page'] as num?)?.toInt() ?? 0;
        final endPage = (s['end_page'] as num?)?.toInt() ?? 0;
        if (endPage > startPage) totalPages += endPage - startPage;
      }

      return {
        'minutes': totalMinutes,
        'pages': totalPages,
        'sessions': allSessions.length,
        'books': finishedBooks.length,
      };
    } catch (e) {
      debugPrint('Erreur _getAllTimeTotals: $e');
      return {'minutes': 0, 'pages': 0, 'sessions': 0, 'books': 0};
    }
  }
}

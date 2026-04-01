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

  Future<ReadingStatistics> getStatistics({int? year, String? readingFor}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecte');

    final now = DateTime.now();
    final targetYear = year ?? now.year;

    // Rolling 6-month window when no specific year is requested
    final String startIso;
    final String endIso;
    if (year != null) {
      startIso = DateTime.utc(year).toIso8601String();
      endIso = DateTime.utc(year + 1).toIso8601String();
    } else {
      startIso = DateTime.utc(now.year, now.month - 5, 1).toIso8601String();
      endIso = DateTime.utc(now.year, now.month + 1, 1).toIso8601String();
    }

    final List<dynamic> results;
    try {
      results = await Future.wait([
        _goalsService.getActiveGoalsWithProgress(year: targetYear), // 0
        _getCompletedSessions(userId, startIso, endIso),            // 1
        _badgesService.getUserBadges(),                              // 2
        _flowService.getUserFlow(),                              // 3
        _getAllTimeTotals(userId),                                    // 4
      ]);
    } catch (e) {
      debugPrint('❌ Future.wait failed: $e');
      rethrow;
    }

    final goals = results[0] as List<ReadingGoal>;
    var sessions = results[1] as List<Map<String, dynamic>>;
    final badges = results[2] as List<UserBadge>;
    final flow = results[3] as dynamic;
    final allTimeTotals = results[4] as Map<String, int>;

    // Filter sessions by readingFor if specified
    if (readingFor != null) {
      sessions = sessions.where((s) => s['reading_for'] == readingFor).toList();
    }

    // Aggregate session data
    final Map<int, int> monthlyPages = {};
    final Map<String, int> genreMinutes = {};
    final Map<int, Map<int, int>> heatmap = {};
    final Map<String, int> readingForMinutes = {};
    final Map<String, int> readingForPages = {};
    final Map<String, int> readingForSessions = {};
    int longestSessionMin = 0;
    DateTime? longestSessionDate;

    for (final s in sessions) {
      try {
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
        final booksData = s['books'];
        final genre = (booksData is Map ? booksData['genre'] as String? : null) ?? 'Autre';
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
            (heatmap[weekday]![timeSlot] ?? 0) + durationMin;

        // Reading for stats
        final readingFor = s['reading_for'] as String?;
        if (readingFor != null && readingFor.isNotEmpty) {
          readingForMinutes[readingFor] = (readingForMinutes[readingFor] ?? 0) + durationMin;
          readingForPages[readingFor] = (readingForPages[readingFor] ?? 0) + pagesRead;
          readingForSessions[readingFor] = (readingForSessions[readingFor] ?? 0) + 1;
        }

        // Longest session
        if (durationMin > longestSessionMin) {
          longestSessionMin = durationMin;
          longestSessionDate = startTime;
        }
      } catch (e) {
        debugPrint('Erreur traitement session: $e');
        continue;
      }
    }

    // Fallback: si aucune session cette année, heatmap all-time (sauf si filtre actif)
    if (heatmap.isEmpty && readingFor == null) {
      try {
        final allSessions = await _supabase
            .from('reading_sessions')
            .select('start_time, end_time')
            .eq('user_id', userId)
            .not('end_time', 'is', null);
        for (final s in List<Map<String, dynamic>>.from(allSessions as List)) {
          final startTime =
              DateTime.parse(s['start_time'] as String).toLocal();
          final endTime = DateTime.parse(s['end_time'] as String).toLocal();
          final durationMin = endTime.difference(startTime).inMinutes;
          if (durationMin <= 0) continue;
          final weekday = startTime.weekday;
          final hour = startTime.hour;
          final int timeSlot;
          if (hour >= 6 && hour < 12) {
            timeSlot = 0;
          } else if (hour >= 12 && hour < 17) {
            timeSlot = 1;
          } else if (hour >= 17 && hour < 22) {
            timeSlot = 2;
          } else {
            timeSlot = 3;
          }
          heatmap.putIfAbsent(weekday, () => {});
          heatmap[weekday]![timeSlot] =
              (heatmap[weekday]![timeSlot] ?? 0) + durationMin;
        }
      } catch (e) {
        debugPrint('Erreur heatmap fallback: $e');
      }
    }

    // Build pages per month
    final pagesPerMonth = <MonthlyPageCount>[];
    if (year != null) {
      for (int m = 1; m <= 12; m++) {
        pagesPerMonth.add(MonthlyPageCount(
          label: _frenchMonths[m],
          month: m,
          pages: monthlyPages[m] ?? 0,
        ));
      }
    } else {
      for (int i = 0; i < 6; i++) {
        final monthDate = DateTime(now.year, now.month - 5 + i, 1);
        final m = monthDate.month;
        pagesPerMonth.add(MonthlyPageCount(
          label: _frenchMonths[m],
          month: m,
          pages: monthlyPages[m] ?? 0,
        ));
      }
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
    final PersonalRecords records;
    if (readingFor != null) {
      // When filtered: compute from filtered sessions only
      int filteredPages = 0;
      int filteredMinutes = 0;
      for (final s in sessions) {
        try {
          final st = DateTime.parse(s['start_time'] as String);
          final et = DateTime.parse(s['end_time'] as String);
          final dur = et.difference(st).inMinutes;
          if (dur > 0) filteredMinutes += dur;
          final sp = (s['start_page'] as num?)?.toInt() ?? 0;
          final ep = (s['end_page'] as num?)?.toInt() ?? 0;
          if (ep > sp) filteredPages += ep - sp;
        } catch (_) {}
      }
      records = PersonalRecords(
        longestSessionMinutes: longestSessionMin,
        longestSessionDate: longestSessionDate,
        bestFlow: 0,
        totalPagesAllTime: filteredPages,
        totalSessionsAllTime: sessions.length,
        totalBooksFinished: 0,
        totalMinutesAllTime: filteredMinutes,
      );
    } else {
      final allTimeLongestMin = allTimeTotals['longestSessionMin'] ?? 0;
      records = PersonalRecords(
        longestSessionMinutes: allTimeLongestMin > longestSessionMin ? allTimeLongestMin : longestSessionMin,
        longestSessionDate: longestSessionDate,
        bestFlow: flow.longestFlow as int,
        totalPagesAllTime: allTimeTotals['pages'] ?? 0,
        totalSessionsAllTime: allTimeTotals['sessions'] ?? 0,
        totalBooksFinished: allTimeTotals['books'] ?? 0,
        totalMinutesAllTime: allTimeTotals['minutes'] ?? 0,
      );
    }

    // Build reading-for stats sorted by minutes desc
    final readingForEntries = readingForMinutes.keys.map((key) {
      return ReadingForStatEntry(
        key: key,
        totalMinutes: readingForMinutes[key] ?? 0,
        totalPages: readingForPages[key] ?? 0,
        totalSessions: readingForSessions[key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    return ReadingStatistics(
      activeGoals: goals,
      pagesPerMonth: pagesPerMonth,
      genreDistribution: genreDistribution,
      readingHeatmap: heatmap,
      records: records,
      unlockedBadges: unlockedBadges.length,
      totalBadges: badges.length,
      recentBadges: recentUnlocked.take(3).toList(),
      readingForStats: readingForEntries,
      sessionCount: sessions.length,
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
              'start_time, end_time, start_page, end_page, book_id, reading_for')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', startIso)
          .lt('start_time', endIso)
          .order('start_time');

      final sessions = List<Map<String, dynamic>>.from(response as List);

      // Fetch book genres separately (no FK between reading_sessions and books)
      final bookIds = sessions
          .map((s) => s['book_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      if (bookIds.isNotEmpty) {
        try {
          final booksResponse = await _supabase
              .from('user_books')
              .select('book_id, books(genre)')
              .eq('user_id', userId)
              .inFilter('book_id', bookIds.map((id) => int.tryParse(id!) ?? 0).where((id) => id > 0).toList());

          final genreMap = <String, String>{};
          for (final ub in (booksResponse as List)) {
            final bookId = ub['book_id']?.toString();
            final booksData = ub['books'];
            final genre = booksData is Map ? booksData['genre']?.toString() : null;
            if (bookId != null && genre != null) {
              genreMap[bookId] = genre;
            }
          }

          // Merge genre back into sessions
          for (final s in sessions) {
            final bookId = s['book_id']?.toString();
            if (bookId != null && genreMap.containsKey(bookId)) {
              s['books'] = {'genre': genreMap[bookId]};
            }
          }
        } catch (e) {
          debugPrint('Erreur fetch book genres: $e');
        }
      }

      return sessions;
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
            .select('start_time, end_time, start_page, end_page, book_id')
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

      // Count sessions per book to filter finished books with < 3 sessions
      final sessionCountPerBook = <String, int>{};

      int longestSessionMin = 0;
      DateTime? longestSessionDate;

      for (final s in allSessions) {
        final stStr = s['start_time']?.toString();
        final etStr = s['end_time']?.toString();
        if (stStr == null || etStr == null) continue;
        final st = DateTime.tryParse(stStr);
        final et = DateTime.tryParse(etStr);
        if (st == null || et == null) continue;
        final durationMin = et.difference(st).inMinutes;
        totalMinutes += durationMin;

        if (durationMin > longestSessionMin) {
          longestSessionMin = durationMin;
          longestSessionDate = st.toLocal();
        }

        final startPage = (s['start_page'] as num?)?.toInt() ?? 0;
        final endPage = (s['end_page'] as num?)?.toInt() ?? 0;
        if (endPage > startPage) totalPages += endPage - startPage;

        final bookId = s['book_id']?.toString() ?? '';
        if (bookId.isNotEmpty) {
          sessionCountPerBook[bookId] = (sessionCountPerBook[bookId] ?? 0) + 1;
        }
      }

      // Only count finished books with at least 3 completed sessions
      final validFinishedBooks = finishedBooks.where((b) {
        final bookId = b['book_id']?.toString() ?? '';
        return (sessionCountPerBook[bookId] ?? 0) >= 3;
      }).toList();

      return {
        'minutes': totalMinutes,
        'pages': totalPages,
        'sessions': allSessions.length,
        'books': validFinishedBooks.length,
        'longestSessionMin': longestSessionMin,
      };
    } catch (e) {
      debugPrint('Erreur _getAllTimeTotals: $e');
      return {'minutes': 0, 'pages': 0, 'sessions': 0, 'books': 0};
    }
  }
}

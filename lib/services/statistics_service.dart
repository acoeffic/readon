import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/reading_statistics.dart';
import '../models/reading_goal.dart';
import 'badges_service.dart';
import 'books_service.dart';
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
  final BooksService _booksService = BooksService();

  ({DateTime start, DateTime end}) _periodRange(StatsPeriod p, DateTime now) {
    switch (p) {
      case StatsPeriod.thisWeek:
        // ISO week: Monday 00:00 to next Monday 00:00
        final weekday = now.weekday; // 1=Mon..7=Sun
        final start = DateTime(now.year, now.month, now.day - (weekday - 1));
        final end = start.add(const Duration(days: 7));
        return (start: start, end: end);
      case StatsPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start: start, end: end);
      case StatsPeriod.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return (start: start, end: end);
      case StatsPeriod.allTime:
        return (start: DateTime(2000), end: DateTime(now.year + 1, 1, 1));
    }
  }

  ({DateTime start, DateTime end}) _chartRange(DateTime now) {
    return (
      start: DateTime(now.year, now.month - 5, 1),
      end: DateTime(now.year, now.month + 1, 1),
    );
  }

  Future<CurrentBookRhythm?> _getCurrentBookRhythm(String userId) async {
    try {
      final current = await _booksService.getCurrentReadingBook();
      if (current == null) return null;

      final book = current['book'] as Book;
      final currentPage = (current['current_page'] as num?)?.toInt() ?? 0;
      final totalPages = (current['total_pages'] as num?)?.toInt() ?? 0;

      final response = await _supabase
          .from('reading_sessions')
          .select('start_time, end_time, start_page, end_page')
          .eq('user_id', userId)
          .eq('book_id', book.id.toString())
          .not('end_time', 'is', null)
          .order('start_time', ascending: true);

      final sessions = List<Map<String, dynamic>>.from(response as List);

      int totalMinutes = 0;
      int totalPagesRead = 0;
      final speeds = <SessionSpeedPoint>[];

      for (final s in sessions) {
        try {
          final st = DateTime.parse(s['start_time'] as String).toLocal();
          final et = DateTime.parse(s['end_time'] as String).toLocal();
          final mins = et.difference(st).inMinutes;
          if (mins <= 0) continue;
          final sp = (s['start_page'] as num?)?.toInt() ?? 0;
          final ep = (s['end_page'] as num?)?.toInt() ?? 0;
          final pages = ep > sp ? ep - sp : 0;
          if (pages == 0) continue;

          totalMinutes += mins;
          totalPagesRead += pages;
          speeds.add(SessionSpeedPoint(
            date: st,
            pagesPerHour: pages / (mins / 60),
          ));
        } catch (_) {}
      }

      final avgSpeed = totalMinutes > 0
          ? (totalPagesRead / (totalMinutes / 60)).round()
          : 0;
      double? remaining;
      if (totalPages > 0 && avgSpeed > 0 && currentPage < totalPages) {
        remaining = (totalPages - currentPage) / avgSpeed;
      }

      return CurrentBookRhythm(
        bookId: book.id,
        title: book.title,
        author: book.author,
        coverUrl: book.coverUrl,
        currentPage: currentPage,
        totalPages: totalPages,
        sessionSpeeds: speeds,
        averagePagesPerHour: avgSpeed,
        sessionCount: speeds.length,
        remainingHours: remaining,
      );
    } catch (e) {
      debugPrint('Erreur _getCurrentBookRhythm: $e');
      return null;
    }
  }

  Future<int> _getPagesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final res = await _supabase
          .from('reading_sessions')
          .select('start_page, end_page')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', start.toUtc().toIso8601String())
          .lt('start_time', end.toUtc().toIso8601String());
      int total = 0;
      for (final s in (res as List)) {
        final sp = (s['start_page'] as num?)?.toInt() ?? 0;
        final ep = (s['end_page'] as num?)?.toInt() ?? 0;
        if (ep > sp) total += ep - sp;
      }
      return total;
    } catch (e) {
      debugPrint('Erreur _getPagesInRange: $e');
      return 0;
    }
  }

  Future<ReadingStatistics> getStatistics({
    StatsPeriod period = StatsPeriod.thisYear,
    String? readingFor,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecte');

    final now = DateTime.now();
    final pr = _periodRange(period, now);
    final cr = _chartRange(now);
    final periodStartIso = pr.start.toUtc().toIso8601String();
    final periodEndIso = pr.end.toUtc().toIso8601String();
    final chartStartIso = cr.start.toUtc().toIso8601String();
    final chartEndIso = cr.end.toUtc().toIso8601String();

    final List<dynamic> results;
    try {
      results = await Future.wait([
        _goalsService.getActiveGoalsWithProgress(year: now.year), // 0
        _getCompletedSessions(userId, periodStartIso, periodEndIso), // 1
        _badgesService.getUserBadges(),                                // 2
        _flowService.getUserFlow(),                                    // 3
        _getAllTimeTotals(userId),                                      // 4
        _getCompletedSessions(userId, chartStartIso, chartEndIso),    // 5
        period == StatsPeriod.thisYear
            ? _getPagesInRange(
                userId,
                DateTime(now.year - 1, 1, 1),
                DateTime(now.year, 1, 1),
              )
            : Future.value(null),                                      // 6
        _getCurrentBookRhythm(userId),                                 // 7
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
    final chartSessions = results[5] as List<Map<String, dynamic>>;
    final previousYearPages = results[6] as int?;
    final currentBookRhythm = results[7] as CurrentBookRhythm?;

    // Filter sessions by readingFor if specified
    if (readingFor != null) {
      sessions = sessions.where((s) => s['reading_for'] == readingFor).toList();
    }

    // Aggregate session data
    final Map<String, int> genreMinutes = {};
    final Map<int, Map<int, int>> heatmap = {};
    final Map<String, int> readingForMinutes = {};
    final Map<String, int> readingForPages = {};
    final Map<String, int> readingForSessions = {};
    final Map<String, _AuthorAgg> authorAgg = {};
    int longestSessionMin = 0;
    DateTime? longestSessionDate;
    int pagesInPeriod = 0;

    for (final s in sessions) {
      try {
        final startTime = DateTime.parse(s['start_time'] as String).toLocal();
        final endTime = DateTime.parse(s['end_time'] as String).toLocal();
        final durationMin = endTime.difference(startTime).inMinutes;

        final startPage = (s['start_page'] as num?)?.toInt() ?? 0;
        final endPage = (s['end_page'] as num?)?.toInt() ?? 0;
        final pagesRead = endPage > startPage ? endPage - startPage : 0;

        // Pages count regardless of duration (covers sub-minute sessions
        // and imports where end_time == start_time).
        pagesInPeriod += pagesRead;

        // Time/genre/heatmap aggregates require a valid positive duration.
        if (durationMin <= 0) continue;

        // Genre distribution + author aggregation
        final booksData = s['books'];
        final genre = (booksData is Map ? booksData['genre'] as String? : null) ?? 'Autre';
        genreMinutes[genre] = (genreMinutes[genre] ?? 0) + durationMin;

        final author = booksData is Map ? booksData['author'] as String? : null;
        final bookId = s['book_id']?.toString();
        if (author != null && author.trim().isNotEmpty && bookId != null) {
          final agg = authorAgg.putIfAbsent(author, () => _AuthorAgg());
          agg.minutes += durationMin;
          agg.bookIds.add(bookId);
        }

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

    // Fallback: si aucune session sur la période, heatmap all-time (sauf si filtre actif)
    if (heatmap.isEmpty && readingFor == null && period != StatsPeriod.allTime) {
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

    // Build pages per month — always from rolling 6-month chart sessions
    // (independent of selected period filter, gives a stable backdrop).
    final Map<String, int> chartMonthlyPages = {};
    for (final s in chartSessions) {
      try {
        final st = DateTime.parse(s['start_time'] as String).toLocal();
        final sp = (s['start_page'] as num?)?.toInt() ?? 0;
        final ep = (s['end_page'] as num?)?.toInt() ?? 0;
        final pages = ep > sp ? ep - sp : 0;
        final key = '${st.year}-${st.month}';
        chartMonthlyPages[key] = (chartMonthlyPages[key] ?? 0) + pages;
      } catch (_) {}
    }

    final pagesPerMonth = <MonthlyPageCount>[];
    for (int i = 0; i < 6; i++) {
      final monthDate = DateTime(now.year, now.month - 5 + i, 1);
      final m = monthDate.month;
      final key = '${monthDate.year}-$m';
      pagesPerMonth.add(MonthlyPageCount(
        label: _frenchMonths[m],
        month: m,
        pages: chartMonthlyPages[key] ?? 0,
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

    // Top authors — distinct books per author from period sessions
    final topAuthors = authorAgg.entries
        .map((e) => TopAuthor(
              name: e.key,
              booksRead: e.value.bookIds.length,
              totalMinutes: e.value.minutes,
            ))
        .toList()
      ..sort((a, b) {
        final byBooks = b.booksRead.compareTo(a.booksRead);
        return byBooks != 0 ? byBooks : b.totalMinutes.compareTo(a.totalMinutes);
      });

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
      pagesInPeriod: pagesInPeriod,
      previousPeriodPages: previousYearPages,
      topAuthors: topAuthors.take(3).toList(),
      period: period,
      currentBookRhythm: currentBookRhythm,
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
              .select('book_id, books(genre, author)')
              .eq('user_id', userId)
              .inFilter('book_id', bookIds.map((id) => int.tryParse(id!) ?? 0).where((id) => id > 0).toList());

          final bookMeta = <String, Map<String, String?>>{};
          for (final ub in (booksResponse as List)) {
            final bookId = ub['book_id']?.toString();
            final booksData = ub['books'];
            if (bookId != null && booksData is Map) {
              bookMeta[bookId] = {
                'genre': booksData['genre']?.toString(),
                'author': booksData['author']?.toString(),
              };
            }
          }

          // Merge genre + author back into sessions
          for (final s in sessions) {
            final bookId = s['book_id']?.toString();
            if (bookId != null && bookMeta.containsKey(bookId)) {
              s['books'] = bookMeta[bookId];
            }
          }
        } catch (e) {
          debugPrint('Erreur fetch book metadata: $e');
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

class _AuthorAgg {
  int minutes = 0;
  final Set<String> bookIds = {};
}

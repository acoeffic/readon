import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'monthly_wrapped_data.dart';

class MonthlyWrappedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Build the full [MonthlyWrappedData] for a given month/year.
  Future<MonthlyWrappedData> getMonthlyData(int month, int year) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecte');

    final start = DateTime.utc(year, month);
    final end = DateTime.utc(month == 12 ? year + 1 : year, month == 12 ? 1 : month + 1);
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    // Run independent queries in parallel
    final results = await Future.wait([
      _getCompletedSessions(userId, startIso, endIso), // 0
      _getBooksFinishedCount(userId, startIso, endIso), // 1
      _getBooksInProgressCount(userId),                  // 2
      _getBadges(userId, startIso, endIso),              // 3
      _getPreviousMonthMinutes(userId, month, year),     // 4
    ]);

    final sessions = results[0] as List<Map<String, dynamic>>;
    final booksFinished = results[1] as int;
    final booksInProgress = results[2] as int;
    final badges = results[3] as List<BadgeData>;
    final prevMonthMinutes = results[4] as int;

    // Compute aggregated stats from sessions
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dailyMinutes = List<int>.filled(daysInMonth, 0);
    int totalMinutes = 0;
    int longestSessionMin = 0;
    final Map<int, int> dayOfWeekTotals = {}; // weekday -> total minutes
    final Map<String, int> bookMinutes = {}; // book_id -> total minutes
    final Map<String, Map<String, dynamic>> bookInfos = {}; // book_id -> info

    for (final s in sessions) {
      final startTime = DateTime.parse(s['start_time'] as String).toLocal();
      final endTime = DateTime.parse(s['end_time'] as String).toLocal();
      final durationMin = endTime.difference(startTime).inMinutes;

      if (durationMin <= 0) continue;

      totalMinutes += durationMin;
      if (durationMin > longestSessionMin) longestSessionMin = durationMin;

      // Daily heatmap
      final day = startTime.day;
      if (day >= 1 && day <= daysInMonth) {
        dailyMinutes[day - 1] += durationMin;
      }

      // Best day of week
      final wd = startTime.weekday;
      dayOfWeekTotals[wd] = (dayOfWeekTotals[wd] ?? 0) + durationMin;

      // Book ranking
      final bookId = s['book_id'] as String;
      bookMinutes[bookId] = (bookMinutes[bookId] ?? 0) + durationMin;
      if (s['books'] != null && !bookInfos.containsKey(bookId)) {
        bookInfos[bookId] = Map<String, dynamic>.from(s['books'] as Map);
      }
    }

    // Best day of week
    int bestDay = 7; // default Sunday
    int bestDayVal = 0;
    dayOfWeekTotals.forEach((wd, mins) {
      if (mins > bestDayVal) {
        bestDayVal = mins;
        bestDay = wd;
      }
    });

    // Top book
    TopBookData? topBook;
    if (bookMinutes.isNotEmpty) {
      final topEntry = bookMinutes.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final info = bookInfos[topEntry.key];
      topBook = TopBookData(
        title: info?['title'] as String? ?? 'Livre inconnu',
        author: info?['author'] as String? ?? '',
        totalMinutes: topEntry.value,
        coverUrl: info?['cover_url'] as String?,
      );
    }

    // Avg session
    final avgSession = sessions.isEmpty ? 0 : totalMinutes ~/ sessions.length;

    // Vs last month
    int vsPercent = 0;
    if (prevMonthMinutes > 0) {
      vsPercent = (((totalMinutes - prevMonthMinutes) / prevMonthMinutes) * 100).round();
    } else if (totalMinutes > 0) {
      vsPercent = 100;
    }

    // Flow data
    final flowData = await _getFlowData(userId, startIso, endIso, daysInMonth);

    return MonthlyWrappedData(
      month: month,
      year: year,
      totalMinutes: totalMinutes,
      sessions: sessions.length,
      avgSessionMinutes: avgSession,
      booksFinished: booksFinished,
      booksInProgress: booksInProgress,
      longestSessionMinutes: longestSessionMin,
      bestDayWeekday: bestDay,
      longestFlow: flowData['longest']!,
      currentFlow: flowData['current']!,
      topBook: topBook,
      vsLastMonthPercent: vsPercent,
      dailyMinutes: dailyMinutes,
      badges: badges,
    );
  }

  // ---------------------------------------------------------------------------
  // Private query helpers
  // ---------------------------------------------------------------------------

  /// All completed sessions in the month window, with book info.
  Future<List<Map<String, dynamic>>> _getCompletedSessions(
    String userId, String startIso, String endIso,
  ) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select('start_time, end_time, book_id, books(title, author, cover_url)')
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

  /// Count books finished (status = 'finished') that had sessions this month.
  Future<int> _getBooksFinishedCount(
    String userId, String startIso, String endIso,
  ) async {
    try {
      // Get finished book IDs for this user
      final finished = await _supabase
          .from('user_books')
          .select('book_id, updated_at')
          .eq('user_id', userId)
          .eq('status', 'finished')
          .gte('updated_at', startIso)
          .lt('updated_at', endIso);

      return (finished as List).length;
    } catch (e) {
      debugPrint('Erreur _getBooksFinishedCount: $e');
      return 0;
    }
  }

  /// Count books currently in progress.
  Future<int> _getBooksInProgressCount(String userId) async {
    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id')
          .eq('user_id', userId)
          .eq('status', 'reading');

      return (response as List).length;
    } catch (e) {
      debugPrint('Erreur _getBooksInProgressCount: $e');
      return 0;
    }
  }

  /// Badges unlocked this month.
  Future<List<BadgeData>> _getBadges(
    String userId, String startIso, String endIso,
  ) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('badge_id, badges(name, icon)')
          .eq('user_id', userId)
          .gte('earned_at', startIso)
          .lt('earned_at', endIso);

      return (response as List).map((row) {
        final badge = row['badges'] as Map<String, dynamic>?;
        return BadgeData(
          icon: badge?['icon'] as String? ?? '',
          name: badge?['name'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Erreur _getBadges: $e');
      return [];
    }
  }

  /// Total minutes from the previous month (for comparison).
  Future<int> _getPreviousMonthMinutes(
    String userId, int month, int year,
  ) async {
    try {
      final prevMonth = month == 1 ? 12 : month - 1;
      final prevYear = month == 1 ? year - 1 : year;
      final prevStart = DateTime.utc(prevYear, prevMonth).toIso8601String();
      final prevEndYear = prevMonth == 12 ? prevYear + 1 : prevYear;
      final prevEndMonth = prevMonth == 12 ? 1 : prevMonth + 1;
      final prevEnd = DateTime.utc(prevEndYear, prevEndMonth).toIso8601String();

      final response = await _supabase
          .from('reading_sessions')
          .select('start_time, end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', prevStart)
          .lt('start_time', prevEnd);

      int total = 0;
      for (final s in response as List) {
        final st = DateTime.parse(s['start_time'] as String);
        final et = DateTime.parse(s['end_time'] as String);
        total += et.difference(st).inMinutes;
      }
      return total;
    } catch (e) {
      debugPrint('Erreur _getPreviousMonthMinutes: $e');
      return 0;
    }
  }

  /// Compute longest flow and current flow for the month.
  Future<Map<String, int>> _getFlowData(
    String userId, String startIso, String endIso, int daysInMonth,
  ) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select('end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', startIso)
          .lt('start_time', endIso);

      // Collect unique days that had reading activity
      final readDays = <int>{};
      for (final s in response as List) {
        final date = DateTime.parse(s['end_time'] as String).toLocal();
        readDays.add(date.day);
      }

      // Longest consecutive run
      int longest = 0;
      int current = 0;
      for (int d = 1; d <= daysInMonth; d++) {
        if (readDays.contains(d)) {
          current++;
          if (current > longest) longest = current;
        } else {
          current = 0;
        }
      }

      // Current flow = consecutive days ending at the last read day
      int currentFlow = 0;
      for (int d = daysInMonth; d >= 1; d--) {
        if (readDays.contains(d)) {
          currentFlow++;
        } else if (currentFlow > 0) {
          break;
        }
      }

      return {'longest': longest, 'current': currentFlow};
    } catch (e) {
      debugPrint('Erreur _getFlowData: $e');
      return {'longest': 0, 'current': 0};
    }
  }
}

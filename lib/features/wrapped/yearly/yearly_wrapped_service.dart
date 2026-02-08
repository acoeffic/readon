import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yearly_wrapped_data.dart';

const _frenchMonths = [
  '', 'Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun',
  'Jul', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _frenchMonthsFull = [
  '', 'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre',
];

class YearlyWrappedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Build the full [YearlyWrappedData] for a given year.
  Future<YearlyWrappedData> getYearlyData(int year) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecte');

    final userMeta = _supabase.auth.currentUser?.userMetadata;
    final userName = userMeta?['first_name'] as String? ??
        userMeta?['full_name'] as String? ??
        userMeta?['name'] as String?;

    final startIso = DateTime.utc(year).toIso8601String();
    final endIso = DateTime.utc(year + 1).toIso8601String();

    // Run independent queries in parallel
    final results = await Future.wait([
      _getCompletedSessions(userId, startIso, endIso), // 0
      _getBooksFinished(userId, startIso, endIso), // 1
      _getBadges(userId, startIso, endIso), // 2
      _getPreviousYearStats(userId, year - 1), // 3
      _getPercentileRank(userId, year), // 4
    ]);

    final sessions = results[0] as List<Map<String, dynamic>>;
    final finishedBooks = results[1] as List<Map<String, dynamic>>;
    final badges = results[2] as List<Map<String, dynamic>>;
    final prevStats = results[3] as Map<String, int>;
    final percentileData = results[4] as Map<String, int>;

    // --- Compute aggregated stats from sessions ---
    int totalMinutes = 0;
    int longestSessionMin = 0;
    DateTime? longestSessionDate;
    final Map<int, int> hourBuckets = {}; // hour -> count
    final Set<String> activeDates = {};
    final Map<String, int> bookMinutes = {};
    final Map<String, Map<String, dynamic>> bookInfos = {};
    final Map<String, int> genreMinutes = {};
    int nightSessions = 0; // sessions between 21h-5h

    for (final s in sessions) {
      final startTime =
          DateTime.parse(s['start_time'] as String).toLocal();
      final endTime =
          DateTime.parse(s['end_time'] as String).toLocal();
      final durationMin = endTime.difference(startTime).inMinutes;
      if (durationMin <= 0) continue;

      totalMinutes += durationMin;
      activeDates
          .add('${startTime.year}-${startTime.month}-${startTime.day}');

      // Hour bucket for reader profile
      hourBuckets[startTime.hour] =
          (hourBuckets[startTime.hour] ?? 0) + 1;

      // Night sessions (21h-5h)
      if (startTime.hour >= 21 || startTime.hour < 5) {
        nightSessions++;
      }

      // Longest session
      if (durationMin > longestSessionMin) {
        longestSessionMin = durationMin;
        longestSessionDate = startTime;
      }

      // Book ranking
      final bookId = s['book_id'] as String;
      bookMinutes[bookId] = (bookMinutes[bookId] ?? 0) + durationMin;
      if (s['books'] != null && !bookInfos.containsKey(bookId)) {
        bookInfos[bookId] =
            Map<String, dynamic>.from(s['books'] as Map);
      }

      // Genre minutes
      final genre =
          (s['books'] as Map?)?['genre'] as String? ?? 'Autre';
      genreMinutes[genre] = (genreMinutes[genre] ?? 0) + durationMin;
    }

    // Avg session
    final avgSession =
        sessions.isEmpty ? 0 : totalMinutes ~/ sessions.length;

    // Active days
    final activeDays = activeDates.length;

    // Night sessions percent
    final nightPct = sessions.isEmpty
        ? 0
        : (nightSessions / sessions.length * 100).round();

    // Peak hour – most common reading hour
    int peakHourVal = 22;
    if (hourBuckets.isNotEmpty) {
      int maxCount = 0;
      hourBuckets.forEach((hour, count) {
        if (count > maxCount) {
          maxCount = count;
          peakHourVal = hour;
        }
      });
    }
    final peakHourStr = '${peakHourVal}h${(peakHourVal >= 12 ? '30' : '00')}';

    // Reader type & emoji
    String readerType;
    String readerEmoji;
    if (peakHourVal >= 21 || peakHourVal < 5) {
      readerType = 'Night Owl Reader';
      readerEmoji = '\uD83C\uDF19';
    } else if (peakHourVal >= 5 && peakHourVal < 10) {
      readerType = 'Early Bird Reader';
      readerEmoji = '\uD83C\uDF05';
    } else if (peakHourVal >= 10 && peakHourVal < 14) {
      readerType = 'Midday Reader';
      readerEmoji = '\u2600\uFE0F';
    } else {
      readerType = 'Afternoon Reader';
      readerEmoji = '\uD83C\uDF24\uFE0F';
    }

    // Longest session date label
    String longestSessionDateLabel = '';
    if (longestSessionDate != null) {
      longestSessionDateLabel =
          '${longestSessionDate.day} ${_frenchMonthsFull[longestSessionDate.month]}';
    }

    // Books per month (with French labels)
    final booksPerMonth = <MonthlyBookCount>[];
    final monthCounts = <int, int>{};
    for (final b in finishedBooks) {
      final updatedAt = b['updated_at'] as String?;
      if (updatedAt != null) {
        final date = DateTime.parse(updatedAt).toLocal();
        monthCounts[date.month] = (monthCounts[date.month] ?? 0) + 1;
      }
    }
    for (int m = 1; m <= 12; m++) {
      booksPerMonth.add(
        MonthlyBookCount(label: _frenchMonths[m], count: monthCounts[m] ?? 0),
      );
    }

    // Top 5 genres
    final sortedGenres = genreMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(5).map((e) {
      final pct =
          totalMinutes > 0 ? (e.value / totalMinutes * 100) : 0.0;
      return GenreData(
        name: e.key,
        totalMinutes: e.value,
        percentage: double.parse(pct.toStringAsFixed(1)),
      );
    }).toList();

    // Top 5 books
    final sortedBooks = bookMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topBooks = sortedBooks.take(5).map((e) {
      final info = bookInfos[e.key];
      return TopBookData(
        title: info?['title'] as String? ?? 'Livre inconnu',
        author: info?['author'] as String? ?? '',
        totalMinutes: e.value,
        coverUrl: info?['cover_url'] as String?,
      );
    }).toList();

    // Flow data (returns best flow + start/end dates)
    final flowResult = _computeBestFlowWithDates(sessions, year);
    final bestFlow = flowResult['flow'] as int;
    final bestFlowPeriod = flowResult['period'] as String;

    // Milestones
    final milestones = _buildMilestones(
      bestFlow: bestFlow,
      bestFlowPeriod: bestFlowPeriod,
      longestSessionMin: longestSessionMin,
      longestSessionDateLabel: longestSessionDateLabel,
      booksFinished: finishedBooks.length,
      booksPerMonth: monthCounts,
      badges: badges,
      topGenres: topGenres,
    );

    return YearlyWrappedData(
      year: year,
      userName: userName,
      totalMinutes: totalMinutes,
      totalSessions: sessions.length,
      avgSessionMinutes: avgSession,
      booksFinished: finishedBooks.length,
      booksPerMonth: booksPerMonth,
      topGenres: topGenres,
      readerType: readerType,
      readerEmoji: readerEmoji,
      nightSessionsPercent: nightPct,
      peakHour: peakHourStr,
      activeDays: activeDays,
      bestFlow: bestFlow,
      bestFlowPeriod: bestFlowPeriod,
      longestSessionMinutes: longestSessionMin,
      longestSessionDateLabel: longestSessionDateLabel,
      topBooks: topBooks,
      milestones: milestones,
      percentileRank: percentileData['rank'] ?? 50,
      totalUsersCompared: percentileData['total'] ?? 0,
      previousYearMinutes: prevStats['minutes'] ?? 0,
      previousYearBooks: prevStats['books'] ?? 0,
      previousYearSessions: prevStats['sessions'] ?? 0,
      previousYearFlow: prevStats['flow'] ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Private query helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getCompletedSessions(
    String userId,
    String startIso,
    String endIso,
  ) async {
    try {
      final response = await _supabase
          .from('reading_sessions')
          .select(
              'start_time, end_time, book_id, books(title, author, cover_url, genre)')
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

  Future<List<Map<String, dynamic>>> _getBooksFinished(
    String userId,
    String startIso,
    String endIso,
  ) async {
    try {
      final response = await _supabase
          .from('user_books')
          .select('book_id, updated_at')
          .eq('user_id', userId)
          .eq('status', 'finished')
          .gte('updated_at', startIso)
          .lt('updated_at', endIso);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Erreur _getBooksFinished: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getBadges(
    String userId,
    String startIso,
    String endIso,
  ) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('badge_id, earned_at, badges(name, icon)')
          .eq('user_id', userId)
          .gte('earned_at', startIso)
          .lt('earned_at', endIso);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Erreur _getBadges: $e');
      return [];
    }
  }

  Future<Map<String, int>> _getPreviousYearStats(
    String userId,
    int prevYear,
  ) async {
    try {
      final startIso = DateTime.utc(prevYear).toIso8601String();
      final endIso = DateTime.utc(prevYear + 1).toIso8601String();

      final sessionsRes = await _supabase
          .from('reading_sessions')
          .select('start_time, end_time')
          .eq('user_id', userId)
          .not('end_time', 'is', null)
          .gte('start_time', startIso)
          .lt('start_time', endIso);

      int totalMin = 0;
      final readDays = <String>{};
      for (final s in sessionsRes as List) {
        final st = DateTime.parse(s['start_time'] as String).toLocal();
        final et = DateTime.parse(s['end_time'] as String).toLocal();
        totalMin += et.difference(st).inMinutes;
        readDays.add('${st.year}-${st.month}-${st.day}');
      }

      final prevFlow = _computeBestFlowFromDates(readDays, prevYear);

      final booksRes = await _supabase
          .from('user_books')
          .select('book_id')
          .eq('user_id', userId)
          .eq('status', 'finished')
          .gte('updated_at', startIso)
          .lt('updated_at', endIso);

      return {
        'minutes': totalMin,
        'books': (booksRes as List).length,
        'sessions': (sessionsRes as List).length,
        'flow': prevFlow,
      };
    } catch (e) {
      debugPrint('Erreur _getPreviousYearStats: $e');
      return {'minutes': 0, 'books': 0, 'sessions': 0, 'flow': 0};
    }
  }

  Future<Map<String, int>> _getPercentileRank(
    String userId,
    int year,
  ) async {
    try {
      final startIso = DateTime.utc(year).toIso8601String();
      final endIso = DateTime.utc(year + 1).toIso8601String();

      final response = await _supabase
          .from('reading_sessions')
          .select('user_id, start_time, end_time')
          .not('end_time', 'is', null)
          .gte('start_time', startIso)
          .lt('start_time', endIso);

      final userTotals = <String, int>{};
      for (final s in response as List) {
        final uid = s['user_id'] as String;
        final st = DateTime.parse(s['start_time'] as String);
        final et = DateTime.parse(s['end_time'] as String);
        userTotals[uid] =
            (userTotals[uid] ?? 0) + et.difference(st).inMinutes;
      }

      if (userTotals.isEmpty || !userTotals.containsKey(userId)) {
        return {'rank': 50, 'total': userTotals.length};
      }

      final myTotal = userTotals[userId]!;
      final belowMe =
          userTotals.values.where((v) => v < myTotal).length;
      final percentile =
          ((belowMe / userTotals.length) * 100).round();
      final rank = 100 - percentile;

      return {'rank': rank.clamp(1, 99), 'total': userTotals.length};
    } catch (e) {
      debugPrint('Erreur _getPercentileRank: $e');
      return {'rank': 50, 'total': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // Flow computation
  // ---------------------------------------------------------------------------

  /// Returns {'flow': int, 'period': String} with the best flow and a
  /// human-readable period like "Du 5 au 28 mars".
  Map<String, dynamic> _computeBestFlowWithDates(
    List<Map<String, dynamic>> sessions,
    int year,
  ) {
    final readDays = <String>{};
    for (final s in sessions) {
      final st = DateTime.parse(s['start_time'] as String).toLocal();
      readDays.add('${st.year}-${st.month}-${st.day}');
    }

    int best = 0;
    int current = 0;
    DateTime? bestStart;
    DateTime? bestEnd;
    DateTime? currentStart;

    final start = DateTime(year);
    final end = DateTime(year + 1);
    var day = start;
    while (day.isBefore(end)) {
      final key = '${day.year}-${day.month}-${day.day}';
      if (readDays.contains(key)) {
        if (current == 0) currentStart = day;
        current++;
        if (current > best) {
          best = current;
          bestStart = currentStart;
          bestEnd = day;
        }
      } else {
        current = 0;
      }
      day = day.add(const Duration(days: 1));
    }

    String period = '';
    if (bestStart != null && bestEnd != null) {
      if (bestStart.month == bestEnd.month) {
        period =
            'Du ${bestStart.day} au ${bestEnd.day} ${_frenchMonthsFull[bestStart.month]}';
      } else {
        period =
            'Du ${bestStart.day} ${_frenchMonthsFull[bestStart.month]} au ${bestEnd.day} ${_frenchMonthsFull[bestEnd.month]}';
      }
    }

    return {'flow': best, 'period': period};
  }

  int _computeBestFlowFromDates(Set<String> readDays, int year) {
    int best = 0;
    int current = 0;

    final start = DateTime(year);
    final end = DateTime(year + 1);
    var day = start;
    while (day.isBefore(end)) {
      final key = '${day.year}-${day.month}-${day.day}';
      if (readDays.contains(key)) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
      day = day.add(const Duration(days: 1));
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Milestones builder
  // ---------------------------------------------------------------------------

  List<MilestoneData> _buildMilestones({
    required int bestFlow,
    required String bestFlowPeriod,
    required int longestSessionMin,
    required String longestSessionDateLabel,
    required int booksFinished,
    required Map<int, int> booksPerMonth,
    required List<Map<String, dynamic>> badges,
    required List<GenreData> topGenres,
  }) {
    final milestones = <MilestoneData>[];

    // Best flow
    if (bestFlow > 0) {
      final dateFromPeriod = bestFlowPeriod.isNotEmpty
          ? bestFlowPeriod.replaceFirst('Du ', '').split(' au ').first
          : null;
      final monthFromPeriod = bestFlowPeriod.isNotEmpty
          ? bestFlowPeriod.split(' ').last
          : null;
      final label = dateFromPeriod != null && monthFromPeriod != null
          ? '$dateFromPeriod ${monthFromPeriod[0].toUpperCase()}${monthFromPeriod.substring(1)}'
          : null;
      milestones.add(MilestoneData(
        icon: '\uD83D\uDD25',
        title: 'Flow de $bestFlow jours consecutifs',
        dateLabel: label,
      ));
    }

    // Longest session
    if (longestSessionMin > 60) {
      final h = longestSessionMin ~/ 60;
      final m = longestSessionMin % 60;
      milestones.add(MilestoneData(
        icon: '\u26A1',
        title: 'Session marathon de ${h}h${m.toString().padLeft(2, '0')}',
        dateLabel: longestSessionDateLabel.isNotEmpty
            ? '${longestSessionDateLabel[0].toUpperCase()}${longestSessionDateLabel.substring(1)}'
            : null,
      ));
    }

    // Best month
    if (booksPerMonth.isNotEmpty) {
      int bestMonth = 1;
      int bestCount = 0;
      booksPerMonth.forEach((month, count) {
        if (count > bestCount) {
          bestCount = count;
          bestMonth = month;
        }
      });
      if (bestCount > 0) {
        final monthName = _frenchMonthsFull[bestMonth];
        milestones.add(MilestoneData(
          icon: '\uD83D\uDCDA',
          title: 'Mois le plus productif \u2014 $bestCount livres',
          dateLabel: '${monthName[0].toUpperCase()}${monthName.substring(1)}',
        ));
      }
    }

    // Badges earned
    if (badges.isNotEmpty) {
      milestones.add(MilestoneData(
        icon: '\uD83C\uDFC5',
        title: '${badges.length} badge${badges.length > 1 ? 's' : ''} debloque${badges.length > 1 ? 's' : ''}',
        dateLabel: null,
      ));
    }

    // Genre diversity
    if (topGenres.length >= 5) {
      milestones.add(MilestoneData(
        icon: '\uD83C\uDF0D',
        title: '${topGenres.length}+ genres explores',
        dateLabel: null,
      ));
    }

    return milestones.take(5).toList();
  }
}

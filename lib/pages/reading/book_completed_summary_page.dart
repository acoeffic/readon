// lib/pages/reading/book_completed_summary_page.dart
// Page de résumé affichée après avoir terminé un livre

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../providers/subscription_provider.dart';
import '../../pages/profile/upgrade_page.dart';
import '../../services/reading_session_service.dart';
import '../../services/badges_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import 'book_finished_share_service.dart';

class BookCompletedSummaryPage extends StatefulWidget {
  final Book book;
  final ReadingSession? lastSession;

  const BookCompletedSummaryPage({
    super.key,
    required this.book,
    this.lastSession,
  });

  @override
  State<BookCompletedSummaryPage> createState() =>
      _BookCompletedSummaryPageState();
}

class _BookCompletedSummaryPageState extends State<BookCompletedSummaryPage>
    with TickerProviderStateMixin {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final BadgesService _badgesService = BadgesService();
  BookReadingStats? _stats;
  List<ReadingSession> _sessions = [];
  List<UserBadge> _unlockedBadges = [];
  bool _isLoading = true;

  late AnimationController _trophyController;
  late Animation<double> _trophyScale;
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _trophyController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _trophyScale = CurvedAnimation(
      parent: _trophyController,
      curve: Curves.elasticOut,
    );
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _loadData();
    _trophyController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _trophyController.dispose();
    _confettiController.dispose();
    _sessionService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _sessionService.getBookStats(widget.book.id.toString()),
        _sessionService.getBookSessions(widget.book.id.toString()),
        _badgesService.getUserBadges(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as BookReadingStats;
        _sessions = (results[1] as List<ReadingSession>)
            .where((s) => s.endPage != null)
            .toList();
        _unlockedBadges = (results[2] as List<UserBadge>)
            .where((b) => b.isUnlocked)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur loadData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '${minutes}min';
  }

  static const _months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];

  String _formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// Compute reading period info from sessions.
  _ReadingPeriod? _computeReadingPeriod() {
    if (_sessions.isEmpty) return null;
    final sorted = List<ReadingSession>.from(_sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final first = sorted.first.startTime;
    final last = sorted.last.startTime;
    final uniqueDays = <String>{};
    for (final s in sorted) {
      uniqueDays.add(
        '${s.startTime.year}-${s.startTime.month}-${s.startTime.day}',
      );
    }
    return _ReadingPeriod(
      firstDate: first,
      lastDate: last,
      readingDays: uniqueDays.length,
    );
  }

  /// Preferred time slot based on session start hours.
  String _computePreferredSlot() {
    if (_sessions.isEmpty) return 'Inconnu';
    final counts = <String, int>{
      'Matin (6h–12h)': 0,
      'Après-midi (12h–18h)': 0,
      'Soir (18h–22h)': 0,
      'Nuit (22h–6h)': 0,
    };
    for (final s in _sessions) {
      final h = s.startTime.hour;
      if (h >= 6 && h < 12) {
        counts['Matin (6h–12h)'] = counts['Matin (6h–12h)']! + 1;
      } else if (h >= 12 && h < 18) {
        counts['Après-midi (12h–18h)'] = counts['Après-midi (12h–18h)']! + 1;
      } else if (h >= 18 && h < 22) {
        counts['Soir (18h–22h)'] = counts['Soir (18h–22h)']! + 1;
      } else {
        counts['Nuit (22h–6h)'] = counts['Nuit (22h–6h)']! + 1;
      }
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Best session: most pages read.
  String _computeBestSession() {
    if (_sessions.isEmpty) return '—';
    final best = _sessions.reduce(
      (a, b) => a.pagesRead >= b.pagesRead ? a : b,
    );
    return '${best.pagesRead} pages en ${_formatDuration(best.durationMinutes)}';
  }

  /// Reading regularity: average reading days per week.
  String _computeRegularity() {
    final period = _computeReadingPeriod();
    if (period == null) return '—';
    final totalDays = period.lastDate.difference(period.firstDate).inDays + 1;
    final weeks = totalDays / 7;
    if (weeks <= 0) return '${period.readingDays} j/sem';
    final daysPerWeek = (period.readingDays / weeks).clamp(0, 7);
    return '${daysPerWeek.toStringAsFixed(1)} j/sem';
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAF6F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── Confetti layer ──
          ...List.generate(30, (i) => _buildConfettiParticle(i)),

          // ── Main content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: [
                        _buildAppBar(isDark),
                        const SizedBox(height: 20),
                        _buildTrophyHeader(isDark),
                        const SizedBox(height: 24),
                        _buildBookCard(isDark),
                        const SizedBox(height: 16),
                        _buildFreeStatsCard(isDark),
                        const SizedBox(height: 12),
                        _buildReadingPeriodCard(isDark),
                        const SizedBox(height: 20),
                        _buildPremiumBilanSection(isDark),
                        const SizedBox(height: 20),
                        if (_unlockedBadges.isNotEmpty) ...[
                          _buildBadgesSection(isDark),
                          const SizedBox(height: 24),
                        ],
                        _buildShareButton(),
                        const SizedBox(height: 12),
                        _buildReturnButton(isDark),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confetti particle ───────────────────────────────────────────────

  Widget _buildConfettiParticle(int index) {
    final rng = math.Random(index + 42);
    final startX = rng.nextDouble();
    final drift = (rng.nextDouble() - 0.5) * 0.3;
    final speed = 0.6 + rng.nextDouble() * 0.4;
    final size = 6.0 + rng.nextDouble() * 6;
    final rotation = rng.nextDouble() * 6 * math.pi;
    final colors = [
      const Color(0xFFD4A54A),
      AppColors.primary,
      Colors.amber,
      Colors.orange.shade300,
      const Color(0xFF8B6914),
      Colors.teal.shade300,
    ];

    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, _) {
        final t = (_confettiController.value * speed).clamp(0.0, 1.0);
        final opacity = t < 0.3 ? (t / 0.3) : (1.0 - t).clamp(0.0, 1.0);
        return Positioned(
          left: MediaQuery.of(context).size.width * (startX + drift * t),
          top: -20 + MediaQuery.of(context).size.height * 0.6 * t,
          child: Transform.rotate(
            angle: rotation * t,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: size,
                height: size * (index.isEven ? 1.0 : 0.6),
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  borderRadius: BorderRadius.circular(index.isEven ? size : 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────

  Widget _buildAppBar(bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const Spacer(),
        Text(
          'LIVRE TERMINÉ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: isDark
                ? const Color(0xFFD4A54A)
                : const Color(0xFF8B6914),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 40),
      ],
    );
  }

  // ── Trophy header ───────────────────────────────────────────────────

  Widget _buildTrophyHeader(bool isDark) {
    return Column(
      children: [
        ScaleTransition(
          scale: _trophyScale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8C84A), Color(0xFFD4A54A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A54A).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 48)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Livre terminé !',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Félicitations, tu as terminé',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Book card ───────────────────────────────────────────────────────

  Widget _buildBookCard(bool isDark) {
    final book = widget.book;
    final pageCount = book.pageCount ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Cover
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CachedBookCover(
              imageUrl: book.coverUrl,
              width: 80,
              height: 110,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (book.author != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    book.author!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                // Progress bar (full)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Terminé',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (pageCount > 0)
                      Text(
                        '$pageCount pages',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Free stats card ─────────────────────────────────────────────────

  Widget _buildFreeStatsCard(bool isDark) {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildFreeStat(
                emoji: '📄',
                value: '${_stats!.totalPagesRead}',
                label: 'pages lues',
                isDark: isDark,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
            Expanded(
              child: _buildFreeStat(
                emoji: '⏱',
                value: _formatDuration(_stats!.totalMinutesRead),
                label: 'de lecture',
                isDark: isDark,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
            Expanded(
              child: _buildFreeStat(
                emoji: '🔄',
                value: '${_stats!.sessionsCount}',
                label: 'sessions',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeStat({
    required String emoji,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Reading period card ─────────────────────────────────────────────

  Widget _buildReadingPeriodCard(bool isDark) {
    final period = _computeReadingPeriod();
    if (period == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatShortDate(period.firstDate)} → ${_formatShortDate(period.lastDate)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${period.readingDays} jours de lecture',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Premium "Bilan du livre" section ────────────────────────────────

  Widget _buildPremiumBilanSection(bool isDark) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Compute premium metrics
    final avgMinPerPage = _stats?.avgMinutesPerPage ?? 0;
    final timePerPageValue = avgMinPerPage < 1
        ? '${(avgMinPerPage * 60).round()} sec/page'
        : '${avgMinPerPage.toStringAsFixed(1)} min/page';

    final avgPagesPerSession = _stats?.avgPagesPerSession ?? 0;
    final paceValue = '${avgPagesPerSession.toStringAsFixed(0)} pages/session';

    final preferredSlot = _computePreferredSlot();
    final bestSession = _computeBestSession();
    final regularity = _computeRegularity();

    final insights = [
      _InsightRow(emoji: '\u{231B}', label: 'Temps moyen par page', value: timePerPageValue),
      _InsightRow(emoji: '\u{1F4C8}', label: 'Rythme moyen', value: paceValue),
      _InsightRow(emoji: '\u{1F319}', label: 'Créneau préféré', value: preferredSlot),
      _InsightRow(emoji: '\u{1F3C5}', label: 'Meilleure session', value: bestSession),
      _InsightRow(emoji: '\u{1F4CA}', label: 'Régularité de lecture', value: regularity),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header with PREMIUM badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A54A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Bilan du livre',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Insight rows
          ...List.generate(insights.length, (i) {
            return Column(
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                  ),
                _buildInsightRow(insights[i], isDark, isPremium),
              ],
            );
          }),
          // CTA for free users
          if (!isPremium) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradePage()),
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9F0D9),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.l),
                    bottomRight: Radius.circular(AppRadius.l),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u{2728} Voir le bilan complet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.brown.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rythme, créneaux, régularité et plus',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.brown.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A54A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Essayer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInsightRow(_InsightRow insight, bool isDark, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(insight.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : Colors.black87,
              ),
            ),
          ),
          if (isPremium)
            Flexible(
              child: Text(
                insight.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFFD4A54A),
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Text(
                  insight.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : const Color(0xFFD4A54A),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Badges section ──────────────────────────────────────────────────

  Widget _buildBadgesSection(bool isDark) {
    final displayBadges = _unlockedBadges.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Badges débloqués',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: displayBadges.map((badge) {
              return Container(
                width: (MediaQuery.of(context).size.width - 24 * 2 - 40 - 10) /
                    2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            badge.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Buttons ─────────────────────────────────────────────────────────

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          if (_stats != null) {
            showBookFinishedShareSheet(
              context: context,
              book: widget.book,
              stats: _stats!,
            );
          }
        },
        icon: const Icon(Icons.share_outlined, size: 20),
        label: const Text(
          'Partager',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildReturnButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.textPrimaryDark : Colors.black87,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
        ),
        child: const Text(
          'Retour à l\'accueil',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────

class _ReadingPeriod {
  final DateTime firstDate;
  final DateTime lastDate;
  final int readingDays;

  const _ReadingPeriod({
    required this.firstDate,
    required this.lastDate,
    required this.readingDays,
  });
}

class _InsightRow {
  final String emoji;
  final String label;
  final String value;

  const _InsightRow({
    required this.emoji,
    required this.label,
    required this.value,
  });
}

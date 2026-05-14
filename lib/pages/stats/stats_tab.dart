import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/feature_flags.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/responsive.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import '../../models/reading_statistics.dart';
import '../../services/native_paywall_service.dart';
import '../../services/statistics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_gate.dart';
import 'widgets/activity_rings_card.dart';
import 'widgets/pages_per_month_chart.dart';
import 'widgets/genre_distribution_chart.dart';
import 'widgets/reading_heatmap.dart';
import 'widgets/personal_records_card.dart';
import 'widgets/badge_overview_card.dart';
import 'widgets/reading_for_stats_card.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final StatisticsService _statisticsService = StatisticsService();
  ReadingStatistics? _stats;
  ReadingStatistics? _unfilteredStats;
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedReadingFor;
  StatsPeriod _selectedPeriod = StatsPeriod.thisYear;

  bool get _isFilteredStatsEmpty {
    if (_stats == null) return true;
    return _stats!.sessionCount == 0;
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({bool refreshAll = false}) async {
    final filter = _selectedReadingFor;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Always load unfiltered stats on first load or refresh
      if (_unfilteredStats == null || refreshAll) {
        _unfilteredStats = await _statisticsService.getStatistics(
          period: _selectedPeriod,
        );
      }

      // Load filtered stats if a reading_for filter is active
      final ReadingStatistics stats;
      if (filter != null) {
        stats = await _statisticsService.getStatistics(
          period: _selectedPeriod,
          readingFor: filter,
        );
      } else {
        stats = _unfilteredStats!;
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur _loadStats: $e');
      debugPrint('❌ Stack: $stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _changePeriod(StatsPeriod p) {
    if (p == _selectedPeriod) return;
    setState(() {
      _selectedPeriod = p;
      _unfilteredStats = null; // invalidate cache
    });
    _loadStats(refreshAll: true);
  }

  String _resolveReadingForLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'daughter': return l.readingForDaughter;
      case 'son': return l.readingForSon;
      case 'friend': return l.readingForFriend;
      case 'grandmother': return l.readingForGrandmother;
      case 'grandfather': return l.readingForGrandfather;
      case 'father': return l.readingForFather;
      case 'mother': return l.readingForMother;
      case 'partner': return l.readingForPartner;
      case 'other': return l.readingForOther;
      default: return key;
    }
  }

  String _resolveReadingForEmoji(String key) {
    switch (key) {
      case 'daughter': return '\uD83D\uDC67';
      case 'son': return '\uD83D\uDC66';
      case 'friend': return '\uD83E\uDDD1\u200D\uD83E\uDD1D\u200D\uD83E\uDDD1';
      case 'grandmother': return '\uD83D\uDC75';
      case 'grandfather': return '\uD83D\uDC74';
      case 'father': return '\uD83D\uDC68';
      case 'mother': return '\uD83D\uDC69';
      case 'partner': return '\u2764\uFE0F';
      default: return '\uD83D\uDCD6';
    }
  }

  static const _readingForOptions = [
    'daughter', 'son', 'friend', 'grandmother', 'grandfather',
    'father', 'mother', 'partner', 'other',
  ];

  Widget _buildReadingForFilter(AppLocalizations l) {
    // Only show chips for reading_for values that have actual sessions
    final usedKeys = _unfilteredStats?.readingForStats
        .map((e) => e.key)
        .toSet() ?? <String>{};
    final visibleOptions = _readingForOptions
        .where((key) => usedKeys.contains(key))
        .toList();

    // If no reading_for sessions exist, don't show the filter at all
    if (visibleOptions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: FilterChip(
              label: Text(l.readingForJustMe),
              selected: _selectedReadingFor == null,
              onSelected: (_) {
                setState(() => _selectedReadingFor = null);
                _loadStats();
              },
            ),
          ),
          ...visibleOptions.map((key) => Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: FilterChip(
              avatar: Text(_resolveReadingForEmoji(key), style: const TextStyle(fontSize: 14)),
              label: Text(_resolveReadingForLabel(l, key)),
              selected: _selectedReadingFor == key,
              onSelected: (_) {
                setState(() => _selectedReadingFor = key);
                _loadStats();
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBlurredPremiumCard(
    BuildContext context, {
    required String eyebrow,
    required String headline,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => NativePaywallService.present(
        context,
        highlightedFeature: Feature.advancedStats,
      ),
      child: _StatsCard(
        eyebrow: eyebrow,
        headline: headline,
        child: Stack(
          children: [
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: child,
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.l,
                    vertical: AppSpace.s,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.white, size: 16),
                      SizedBox(width: AppSpace.xs),
                      Text(
                        'Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Editorial helpers ───────────────────────────────────────────────────

  static const _fullMonthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  String _peakMonthHeadline(ReadingStatistics stats) {
    if (stats.pagesPerMonth.isEmpty) return 'Vos lectures, mois après mois';
    final peak = stats.pagesPerMonth.reduce(
      (a, b) => a.pages >= b.pages ? a : b,
    );
    if (peak.pages == 0) return 'Vos lectures, mois après mois';
    final fullName = (peak.month >= 1 && peak.month <= 12)
        ? _fullMonthNames[peak.month - 1]
        : peak.label;
    return '$fullName reste votre mois le plus dense';
  }

  String _topGenreHeadline(ReadingStatistics stats) {
    if (stats.genreDistribution.isEmpty) {
      return 'Ce qui compose votre bibliothèque';
    }
    final top = stats.genreDistribution.first;
    return '${top.name} reste votre boussole';
  }

  ({String eyebrow, int pages, String subtitle}) _heroContent(
    ReadingStatistics stats,
  ) {
    switch (stats.period) {
      case StatsPeriod.thisWeek:
        return (
          eyebrow: 'VOTRE SEMAINE',
          pages: stats.pagesInPeriod,
          subtitle: 'pages, cette semaine',
        );
      case StatsPeriod.thisMonth:
        return (
          eyebrow: 'VOTRE MOIS',
          pages: stats.pagesInPeriod,
          subtitle: 'pages, ce mois',
        );
      case StatsPeriod.thisYear:
        return (
          eyebrow: 'VOTRE ANNÉE EN LECTURE',
          pages: stats.pagesInPeriod,
          subtitle: 'pages, depuis janvier',
        );
      case StatsPeriod.allTime:
        return (
          eyebrow: 'VOTRE BIBLIOTHÈQUE',
          pages: stats.records.totalPagesAllTime,
          subtitle: 'pages, depuis votre première session',
        );
    }
  }

  Widget? _buildYoYChip(ReadingStatistics stats) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    if (!isPremium) return null;
    if (stats.period != StatsPeriod.thisYear) return null;
    final prev = stats.previousPeriodPages;
    if (prev == null || prev <= 0) return null;
    final delta = ((stats.pagesInPeriod - prev) / prev * 100).round();
    final isPositive = delta >= 0;
    final color =
        isPositive ? AppColors.primary : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : ''}$delta% vs. l\'an dernier',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialHero(ReadingStatistics stats) {
    final hero = _heroContent(stats);
    final yoy = _buildYoYChip(stats);
    final color = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.xl,
        AppSpace.l,
        AppSpace.xl,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hero.eyebrow,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            _formatNumber(hero.pages),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 64,
              fontWeight: FontWeight.w600,
              height: 1,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            hero.subtitle,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          if (yoy != null) ...[
            const SizedBox(height: AppSpace.m),
            yoy,
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodChips() {
    final now = DateTime.now();
    final periods = [
      (StatsPeriod.thisWeek, 'Cette semaine'),
      (StatsPeriod.thisMonth, 'Ce mois'),
      (StatsPeriod.thisYear, '${now.year}'),
      (StatsPeriod.allTime, 'Toujours'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.s),
        itemBuilder: (context, i) {
          final (p, label) = periods[i];
          final selected = p == _selectedPeriod;
          final onSurface = Theme.of(context).colorScheme.onSurface;
          return Material(
            color: selected ? onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              onTap: () => _changePeriod(p),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.m,
                  vertical: AppSpace.s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: selected
                      ? null
                      : Border.all(
                          color: onSurface.withValues(alpha: 0.15),
                        ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Theme.of(context).cardColor
                        : onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiStrip(ReadingStatistics stats) {
    final r = stats.records;
    final hours = r.totalMinutesAllTime ~/ 60;
    final rythme = r.totalSessionsAllTime > 0
        ? (r.totalPagesAllTime / r.totalSessionsAllTime).round()
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.l,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _KpiCell(
                label: 'SÉRIE',
                value: '${r.bestFlow}',
                unit: 'j',
              ),
            ),
            const _KpiDivider(),
            Expanded(
              child: _KpiCell(
                label: 'TERMINÉS',
                value: '${r.totalBooksFinished}',
                unit: r.totalBooksFinished > 1 ? 'livres' : 'livre',
              ),
            ),
            const _KpiDivider(),
            Expanded(
              child: _KpiCell(
                label: 'LECTURE',
                value: '$hours',
                unit: 'h',
              ),
            ),
            const _KpiDivider(),
            Expanded(
              child: _KpiCell(
                label: 'RYTHME',
                value: '$rythme',
                unit: 'p./séance',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _topAuthorsHeadline(int count) {
    switch (count) {
      case 1:
        return 'Une plume vous accompagne';
      case 2:
        return 'Deux plumes vous accompagnent';
      default:
        return 'Trois plumes vous accompagnent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l.loadingError),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadStats,
              child: Text(l.retry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStats(refreshAll: true),
      child: ConstrainedContent.wide(
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          children: [
            _buildReadingForFilter(l),
            const SizedBox(height: AppSpace.m),
            if (_selectedReadingFor != null && _isFilteredStatsEmpty) ...[
              const SizedBox(height: AppSpace.xl),
              Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: AppSpace.m),
              Text(
                l.readingForNoStats(
                  _resolveReadingForLabel(l, _selectedReadingFor!).toLowerCase(),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ] else ...[
              if (_selectedReadingFor == null) ...[
                PremiumGate(
                  feature: Feature.advancedStats,
                  lockedWidget: const SizedBox.shrink(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.l),
                    child: _buildPeriodChips(),
                  ),
                ),
                _buildEditorialHero(_stats!),
                const SizedBox(height: AppSpace.l),
                _buildKpiStrip(_stats!),
                const SizedBox(height: AppSpace.l),
                if (Responsive.isWide(context))
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ActivityRingsCard(
                            goals: _stats!.activeGoals,
                            onGoalsUpdated: _loadStats,
                          ),
                        ),
                        const SizedBox(width: AppSpace.l),
                        Expanded(
                          child: BadgeOverviewCard(
                            unlocked: _stats!.unlockedBadges,
                            total: _stats!.totalBadges,
                            recentBadges: _stats!.recentBadges,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ActivityRingsCard(
                    goals: _stats!.activeGoals,
                    onGoalsUpdated: _loadStats,
                  ),
                  const SizedBox(height: AppSpace.l),
                  BadgeOverviewCard(
                    unlocked: _stats!.unlockedBadges,
                    total: _stats!.totalBadges,
                    recentBadges: _stats!.recentBadges,
                  ),
                ],
                const SizedBox(height: AppSpace.l),
              ],
              PremiumGate(
                feature: Feature.advancedStats,
                lockedWidget: _buildBlurredPremiumCard(
                  context,
                  eyebrow: 'PAGES PAR MOIS',
                  headline: _peakMonthHeadline(_stats!),
                  child: PagesPerMonthChart(
                    data: _stats!.pagesPerMonth,
                    embedded: true,
                  ),
                ),
                child: _StatsCard(
                  eyebrow: 'PAGES PAR MOIS',
                  headline: _peakMonthHeadline(_stats!),
                  child: PagesPerMonthChart(
                    data: _stats!.pagesPerMonth,
                    embedded: true,
                  ),
                ),
              ),
              if (_selectedReadingFor == null && _stats!.currentBookRhythm != null) ...[
                const SizedBox(height: AppSpace.l),
                PremiumGate(
                  feature: Feature.advancedStats,
                  lockedWidget: _buildBlurredPremiumCard(
                    context,
                    eyebrow: 'RYTHME — LIVRE EN COURS',
                    headline: _stats!.currentBookRhythm!.title,
                    child: _CurrentBookRhythmCard(
                      rhythm: _stats!.currentBookRhythm!,
                    ),
                  ),
                  child: _CurrentBookRhythmCard(
                    rhythm: _stats!.currentBookRhythm!,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.l),
              PremiumGate(
                feature: Feature.advancedStats,
                lockedWidget: _buildBlurredPremiumCard(
                  context,
                  eyebrow: 'RÉPARTITION DES GENRES',
                  headline: _topGenreHeadline(_stats!),
                  child: GenreDistributionChart(
                    data: _stats!.genreDistribution,
                    embedded: true,
                  ),
                ),
                child: _StatsCard(
                  eyebrow: 'RÉPARTITION DES GENRES',
                  headline: _topGenreHeadline(_stats!),
                  child: GenreDistributionChart(
                    data: _stats!.genreDistribution,
                    embedded: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              PremiumGate(
                feature: Feature.advancedStats,
                lockedWidget: _buildBlurredPremiumCard(
                  context,
                  eyebrow: 'QUAND LISEZ-VOUS ?',
                  headline: 'Vos rendez-vous favoris de la semaine',
                  child: ReadingHeatmap(
                    data: _stats!.readingHeatmap,
                    embedded: true,
                  ),
                ),
                child: _StatsCard(
                  eyebrow: 'QUAND LISEZ-VOUS ?',
                  headline: 'Vos rendez-vous favoris de la semaine',
                  child: ReadingHeatmap(
                    data: _stats!.readingHeatmap,
                    embedded: true,
                  ),
                ),
              ),
              if (_selectedReadingFor == null && _stats!.topAuthors.isNotEmpty) ...[
                const SizedBox(height: AppSpace.l),
                PremiumGate(
                  feature: Feature.advancedStats,
                  lockedWidget: _buildBlurredPremiumCard(
                    context,
                    eyebrow: 'VOS AUTEURS',
                    headline: _topAuthorsHeadline(_stats!.topAuthors.length),
                    child: _TopAuthorsList(authors: _stats!.topAuthors),
                  ),
                  child: _StatsCard(
                    eyebrow: 'VOS AUTEURS',
                    headline: _topAuthorsHeadline(_stats!.topAuthors.length),
                    child: _TopAuthorsList(authors: _stats!.topAuthors),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.l),
              PersonalRecordsCard(records: _stats!.records),
              if (_selectedReadingFor == null && _stats!.readingForStats.isNotEmpty) ...[
                const SizedBox(height: AppSpace.l),
                ReadingForStatsCard(data: _stats!.readingForStats),
              ],
            ],
            const SizedBox(height: AppSpace.l),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final Widget child;

  const _StatsCard({
    required this.eyebrow,
    required this.headline,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpace.l),
          child,
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _KpiCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiDivider extends StatelessWidget {
  const _KpiDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.m),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    );
  }
}

class _TopAuthorsList extends StatelessWidget {
  final List<TopAuthor> authors;

  const _TopAuthorsList({required this.authors});

  static const _avatarColors = [
    Color(0xFFE8C9B5), // peachy
    Color(0xFFC9DDB8), // sage light
    Color(0xFFE3CDB7), // tan
    Color(0xFFD7C2D5), // mauve light
    Color(0xFFC8D7DC), // slate light
  ];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0].toUpperCase();
    final last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0].toUpperCase()
        : '';
    return '$first$last';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: List.generate(authors.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Divider(
            height: 1,
            color: color.withValues(alpha: 0.08),
          );
        }
        final idx = i ~/ 2;
        final a = authors[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _avatarColors[idx % _avatarColors.length],
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(a.name),
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.booksRead > 1
                          ? '${a.booksRead} livres lus'
                          : '${a.booksRead} livre lu',
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Text(
                (idx + 1).toString().padLeft(2, '0'),
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CurrentBookRhythmCard extends StatelessWidget {
  final CurrentBookRhythm rhythm;

  const _CurrentBookRhythmCard({required this.rhythm});

  String _formatRemaining(double hours) {
    if (hours < 1) {
      final mins = (hours * 60).round();
      return '~${mins}min';
    }
    if (hours < 10) return '~${hours.toStringAsFixed(1)}';
    return '~${hours.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final hasChart = rhythm.sessionSpeeds.length >= 2;
    final hasProgress = rhythm.totalPages > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: CachedBookCover(
                  imageUrl: rhythm.coverUrl,
                  title: rhythm.title,
                  author: rhythm.author,
                  width: 56,
                  height: 80,
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RYTHME — LIVRE EN COURS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rhythm.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasProgress) ...[
                const SizedBox(width: AppSpace.s),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${rhythm.progressPercent.round()}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      TextSpan(
                        text: '%',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: color.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (hasChart) ...[
            const SizedBox(height: AppSpace.l),
            SizedBox(
              height: 80,
              child: CustomPaint(
                size: Size.infinite,
                painter: _SpeedLinePainter(
                  speeds: rhythm.sessionSpeeds
                      .map((s) => s.pagesPerHour)
                      .toList(),
                  lineColor: AppColors.sageGreen,
                  fillColor: AppColors.sageGreen.withValues(alpha: 0.12),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.l),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _KpiCell(
                    label: 'VITESSE',
                    value: '${rhythm.averagePagesPerHour}',
                    unit: 'p./h',
                  ),
                ),
                const _KpiDivider(),
                Expanded(
                  child: _KpiCell(
                    label: 'SESSIONS',
                    value: '${rhythm.sessionCount}',
                    unit: '',
                  ),
                ),
                const _KpiDivider(),
                Expanded(
                  child: _KpiCell(
                    label: 'RESTANT',
                    value: rhythm.remainingHours != null
                        ? _formatRemaining(rhythm.remainingHours!)
                        : '—',
                    unit: rhythm.remainingHours != null ? 'h' : '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedLinePainter extends CustomPainter {
  final List<double> speeds;
  final Color lineColor;
  final Color fillColor;

  _SpeedLinePainter({
    required this.speeds,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (speeds.length < 2) return;

    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
    final minSpeed = speeds.reduce((a, b) => a < b ? a : b);
    final range = (maxSpeed - minSpeed).abs() < 0.001 ? 1.0 : maxSpeed - minSpeed;

    const paddingY = 12.0;
    final usableH = size.height - paddingY * 2;
    final stepX = size.width / (speeds.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < speeds.length; i++) {
      final x = i * stepX;
      final t = (speeds[i] - minSpeed) / range;
      final y = size.height - paddingY - t * usableH;
      points.add(Offset(x, y));
    }

    // Smooth path using cubic bezier
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      linePath.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);

    // Fill area beneath the line
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Data points: outer ring + inner fill
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinePainter oldDelegate) =>
      oldDelegate.speeds != speeds || oldDelegate.lineColor != lineColor;
}

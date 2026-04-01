import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/feature_flags.dart';
import '../../widgets/constrained_content.dart';
import '../../models/reading_statistics.dart';
import '../../pages/profile/upgrade_page.dart';
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
        _unfilteredStats = await _statisticsService.getStatistics();
      }

      // Load filtered stats if a reading_for filter is active
      final ReadingStatistics stats;
      if (filter != null) {
        stats = await _statisticsService.getStatistics(readingFor: filter);
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
          ..._readingForOptions.map((key) => Padding(
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
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UpgradePage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.l),
            Stack(
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
          ],
        ),
      ),
    );
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
      child: ConstrainedContent(
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
              // Global cards only when no filter is active
              if (_selectedReadingFor == null) ...[
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
                const SizedBox(height: AppSpace.l),
              ],
              PremiumGate(
                feature: Feature.advancedStats,
                lockedWidget: _buildBlurredPremiumCard(
                  context,
                  title: l.pagesReadByMonth,
                  child: PagesPerMonthChart(
                    data: _stats!.pagesPerMonth,
                    showHeader: false,
                  ),
                ),
                child: PagesPerMonthChart(data: _stats!.pagesPerMonth),
              ),
              const SizedBox(height: AppSpace.l),
              PremiumGate(
                feature: Feature.advancedStats,
                lockedWidget: _buildBlurredPremiumCard(
                  context,
                  title: l.genreDistribution,
                  child: GenreDistributionChart(
                    data: _stats!.genreDistribution,
                    showHeader: false,
                  ),
                ),
                child: GenreDistributionChart(data: _stats!.genreDistribution),
              ),
              const SizedBox(height: AppSpace.l),
              PremiumGate(
                feature: Feature.advancedStats,
                lockedWidget: _buildBlurredPremiumCard(
                  context,
                  title: l.whenDoYouRead,
                  subtitle: l.favoriteSchedules,
                  child: ReadingHeatmap(
                    data: _stats!.readingHeatmap,
                    showHeader: false,
                  ),
                ),
                child: ReadingHeatmap(data: _stats!.readingHeatmap),
              ),
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

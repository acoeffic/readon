import 'dart:ui';

import 'package:flutter/material.dart';
import '../../models/feature_flags.dart';
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

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final StatisticsService _statisticsService = StatisticsService();
  ReadingStatistics? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _statisticsService.getStatistics();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
            const Text('Erreur de chargement'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadStats,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          children: [
            ActivityRingsCard(goals: _stats!.activeGoals),
            const SizedBox(height: AppSpace.l),
            PremiumGate(
              feature: Feature.advancedStats,
              lockedWidget: _buildBlurredPremiumCard(
                context,
                title: 'Pages lues par mois',
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
                title: 'Répartition des genres',
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
                title: 'Quand lis-tu',
                subtitle: 'Tes horaires favoris de la semaine',
                child: ReadingHeatmap(
                  data: _stats!.readingHeatmap,
                  showHeader: false,
                ),
              ),
              child: ReadingHeatmap(data: _stats!.readingHeatmap),
            ),
            const SizedBox(height: AppSpace.l),
            PersonalRecordsCard(records: _stats!.records),
            const SizedBox(height: AppSpace.l),
            BadgeOverviewCard(
              unlocked: _stats!.unlockedBadges,
              total: _stats!.totalBadges,
              recentBadges: _stats!.recentBadges,
            ),
            const SizedBox(height: AppSpace.l),
          ],
        ),
      ),
    );
  }
}

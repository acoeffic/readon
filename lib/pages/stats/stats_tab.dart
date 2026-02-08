import 'package:flutter/material.dart';
import '../../models/reading_statistics.dart';
import '../../services/statistics_service.dart';
import '../../theme/app_theme.dart';
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
            PagesPerMonthChart(data: _stats!.pagesPerMonth),
            const SizedBox(height: AppSpace.l),
            GenreDistributionChart(data: _stats!.genreDistribution),
            const SizedBox(height: AppSpace.l),
            ReadingHeatmap(data: _stats!.readingHeatmap),
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

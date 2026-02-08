import 'package:flutter/material.dart';
import '../../../models/reading_statistics.dart';
import '../../../theme/app_theme.dart';

class PersonalRecordsCard extends StatelessWidget {
  final PersonalRecords records;

  const PersonalRecordsCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Records personnels',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpace.l),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpace.m,
            crossAxisSpacing: AppSpace.m,
            childAspectRatio: 1.8,
            children: [
              _RecordTile(
                emoji: '\u26A1',
                value: records.formattedLongestSession,
                label: 'Plus longue session',
                context: context,
              ),
              _RecordTile(
                emoji: '\uD83D\uDD25',
                value: '${records.bestFlow}j',
                label: 'Meilleur flow',
                context: context,
              ),
              _RecordTile(
                emoji: '\uD83D\uDCD6',
                value: _formatNumber(records.totalPagesAllTime),
                label: 'Pages lues',
                context: context,
              ),
              _RecordTile(
                emoji: '\uD83D\uDCDA',
                value: '${records.totalBooksFinished}',
                label: 'Livres terminés',
                context: context,
              ),
              _RecordTile(
                emoji: '\uD83C\uDFAF',
                value: '${records.totalSessionsAllTime}',
                label: 'Sessions',
                context: context,
              ),
              _RecordTile(
                emoji: '\u23F1\uFE0F',
                value: records.formattedTotalTime,
                label: 'Heures de lecture',
                context: context,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}

class _RecordTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final BuildContext context;

  const _RecordTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

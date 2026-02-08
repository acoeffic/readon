import 'package:flutter/material.dart';
import '../../../models/reading_statistics.dart';
import '../../../theme/app_theme.dart';

const _genreColors = [
  Color(0xFF7FA497), // green
  Color(0xFFFF9F43), // orange
  Color(0xFF5C6BC0), // indigo
  Color(0xFFE57373), // red
  Color(0xFF4DD0E1), // cyan
  Color(0xFFBA68C8), // purple
];

class GenreDistributionChart extends StatelessWidget {
  final List<GenreStatData> data;

  const GenreDistributionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
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
              'Répartition des genres',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpace.l),
            Center(
              child: Text(
                'Pas encore de données',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
            'Répartition des genres',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpace.l),

          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: SizedBox(
              height: 24,
              child: Row(
                children: data.asMap().entries.map((e) {
                  final flex = e.value.percentage.round().clamp(1, 100);
                  return Expanded(
                    flex: flex,
                    child: Container(
                      color: _genreColors[e.key % _genreColors.length],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: AppSpace.m),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: data.asMap().entries.map((e) {
              final color = _genreColors[e.key % _genreColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${e.value.name} (${e.value.percentage.round()}%)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

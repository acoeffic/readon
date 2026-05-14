import 'package:flutter/material.dart';
import '../../../models/reading_statistics.dart';
import '../../../theme/app_theme.dart';

class PagesPerMonthChart extends StatelessWidget {
  final List<MonthlyPageCount> data;
  final bool showHeader;
  final bool embedded;

  const PagesPerMonthChart({
    super.key,
    required this.data,
    this.showHeader = true,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxPages = data.fold<int>(0, (max, m) => m.pages > max ? m.pages : max);
    const maxBarHeight = 140.0;
    final lastIndex = data.length - 1;

    final chart = SizedBox(
      height: maxBarHeight + 56, // bars + value labels + month labels
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final fraction = maxPages > 0 ? m.pages / maxPages : 0.0;
          final barHeight = maxBarHeight * fraction;
          final isCurrent = i == lastIndex;
          final hasPages = m.pages > 0;

          Color barColor;
          if (!hasPages) {
            barColor = AppColors.primary.withValues(alpha: 0.08);
          } else if (isCurrent) {
            barColor = AppColors.sageGreen;
          } else {
            barColor = AppColors.primary.withValues(alpha: 0.35);
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasPages)
                    Text(
                      '${m.pages}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: isCurrent ? 0.85 : 0.55),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: barHeight < 2 && hasPages ? 2 : barHeight,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.3,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: isCurrent ? 0.85 : 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (embedded) return chart;

    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'Pages lues par mois',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpace.l),
          ],
          chart,
        ],
      ),
    );
  }
}

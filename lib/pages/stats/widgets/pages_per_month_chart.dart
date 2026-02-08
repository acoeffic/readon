import 'package:flutter/material.dart';
import '../../../models/reading_statistics.dart';
import '../../../theme/app_theme.dart';

class PagesPerMonthChart extends StatelessWidget {
  final List<MonthlyPageCount> data;

  const PagesPerMonthChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxPages = data.fold<int>(0, (max, m) => m.pages > max ? m.pages : max);
    const maxBarHeight = 120.0;

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
            'Pages lues par mois',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpace.l),
          SizedBox(
            height: maxBarHeight + 50, // bars + labels
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((m) {
                final fraction = maxPages > 0 ? m.pages / maxPages : 0.0;
                final barHeight = maxBarHeight * fraction;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (m.pages > 0)
                          Text(
                            '${m.pages}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: barHeight < 2 && m.pages > 0 ? 2 : barHeight,
                          decoration: BoxDecoration(
                            color: m.pages > 0
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

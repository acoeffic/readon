import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

const _timeSlotLabels = ['Matin', 'Midi', 'Soir', 'Nuit'];
const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

class ReadingHeatmap extends StatelessWidget {
  final Map<int, Map<int, int>> data; // weekday (1-7) -> {timeSlot (0-3) -> count}
  final bool showHeader;

  const ReadingHeatmap({super.key, required this.data, this.showHeader = true});

  int get _maxCount {
    int max = 0;
    for (final dayMap in data.values) {
      for (final count in dayMap.values) {
        if (count > max) max = count;
      }
    }
    return max;
  }

  Color _intensityColor(int count, int maxCount, BuildContext context) {
    if (count == 0) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : AppColors.primary.withValues(alpha: 0.08);
    }
    final ratio = count / maxCount;
    if (ratio > 0.66) {
      return AppColors.primary;
    } else if (ratio > 0.33) {
      return AppColors.primary.withValues(alpha: 0.55);
    } else {
      return AppColors.primary.withValues(alpha: 0.25);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxCount = _maxCount;
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

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
              'Quand lis-tu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tes horaires favoris de la semaine',
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
            const SizedBox(height: AppSpace.l),
          ],

          // Day labels at the top
          Row(
            children: [
              const SizedBox(width: 50),
              ..._dayLabels.map((label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: AppSpace.s),

          // Grid: 4 rows (Matin, Midi, Soir, Nuit) x 7 columns
          Column(
            children: List.generate(4, (slotIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        _timeSlotLabels[slotIndex],
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    ...List.generate(7, (dayIndex) {
                      final weekday = dayIndex + 1; // 1=Mon..7=Sun
                      final count = data[weekday]?[slotIndex] ?? 0;
                      final color = _intensityColor(
                          count, maxCount > 0 ? maxCount : 1, context);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

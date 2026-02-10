import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/reading_goal.dart';
import '../../../theme/app_theme.dart';
import '../../profile/reading_goals_page.dart';

const _ringColors = [
  Color(0xFF7FA497), // green (primary)
  Color(0xFFFF9F43), // orange
  Color(0xFF5C6BC0), // indigo
];

class ActivityRingsCard extends StatelessWidget {
  final List<ReadingGoal> goals;
  final VoidCallback? onGoalsUpdated;

  const ActivityRingsCard({super.key, required this.goals, this.onGoalsUpdated});

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
            'Tes objectifs',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpace.l),
          if (goals.isEmpty) _buildEmptyState(context) else _buildRings(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.track_changes,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)),
          const SizedBox(height: AppSpace.m),
          Text(
            'Aucun objectif défini',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          ElevatedButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReadingGoalsPage()),
              );
              onGoalsUpdated?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Définir tes objectifs'),
          ),
        ],
      ),
    );
  }

  Widget _buildRings(BuildContext context) {
    final displayGoals = goals.take(3).toList();

    return Column(
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(
            painter: _ActivityRingsPainter(
              goals: displayGoals,
              colors: _ringColors,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.l),
        ...displayGoals.asMap().entries.map((entry) {
          final i = entry.key;
          final goal = entry.value;
          final color = _ringColors[i % _ringColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Text(
                  '${goal.goalType.emoji} ${goal.progressText}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ActivityRingsPainter extends CustomPainter {
  final List<ReadingGoal> goals;
  final List<Color> colors;
  final Color backgroundColor;

  _ActivityRingsPainter({
    required this.goals,
    required this.colors,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final strokeWidth = goals.length <= 1 ? 16.0 : (goals.length == 2 ? 14.0 : 12.0);
    final gap = strokeWidth + 6;

    for (int i = 0; i < goals.length && i < 3; i++) {
      final radius = maxRadius - (i * gap) - strokeWidth / 2;
      if (radius <= 0) break;

      final color = colors[i % colors.length];
      final progress = goals[i].progressPercent;

      // Background ring
      final bgPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, bgPaint);

      // Progress arc
      if (progress > 0) {
        final progressPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        final sweepAngle = 2 * math.pi * progress;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          sweepAngle,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) {
    return true;
  }
}

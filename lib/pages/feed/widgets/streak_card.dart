// lib/pages/feed/widgets/streak_card.dart
// Widget pour afficher le streak de lecture dans le feed

import 'package:flutter/material.dart';
import '../../../models/reading_streak.dart';
import '../../../theme/app_theme.dart';

class StreakCard extends StatelessWidget {
  final ReadingStreak streak;
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.streak,
    this.onTap,
  });

  Color _getStreakColor() {
    if (streak.currentStreak >= 30) {
      return AppColors.primary; // Purple
    } else if (streak.currentStreak >= 14) {
      return const Color(0xFFFF5722); // Deep Orange
    } else if (streak.currentStreak >= 7) {
      return const Color(0xFFFFC107); // Amber
    } else if (streak.currentStreak >= 3) {
      return const Color(0xFFFF9800); // Orange
    } else {
      return const Color(0xFF4CAF50); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStreakColor();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculer le début de la semaine (dimanche)
    final daysSinceSunday = now.weekday % 7; // 0 = dimanche
    final weekStart = today.subtract(Duration(days: daysSinceSunday));

    // Générer les 7 jours de la semaine
    final weekDays = List.generate(7, (index) {
      return weekStart.add(Duration(days: index));
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2C3E50).withValues(alpha:0.7),
                const Color(0xFF34495E).withValues(alpha:0.7),
              ],
            ),
          ),
          child: Column(
            children: [
              // En-tête compact avec les statistiques
              Row(
                children: [
                  // Streak actuel
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${streak.currentStreak}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'jours',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider vertical discret
                  Container(
                    height: 20,
                    width: 1,
                    color: Colors.grey.shade700.withValues(alpha:0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  // Streak record
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          '🏆',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${streak.longestStreak}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'record',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Visualisation compacte de la semaine
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: weekDays.asMap().entries.map((entry) {
                  final index = entry.key;
                  final date = entry.value;
                  return _buildDayCircle(date, index, color, today);
                }).toList(),
              ),

              const SizedBox(height: 6),

              // Labels des jours
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['D', 'L', 'M', 'M', 'J', 'V', 'S']
                    .map((day) => SizedBox(
                          width: 24,
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCircle(DateTime date, int index, Color activeColor, DateTime today) {
    // Vérifier si l'utilisateur a lu ce jour-là
    final hasRead = streak.readDates.any((readDate) {
      return readDate.year == date.year &&
          readDate.month == date.month &&
          readDate.day == date.day;
    });

    // Vérifier si ce jour est frozen
    final isFrozen = streak.isDayFrozen(date);

    // Vérifier si c'est aujourd'hui
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    // Vérifier si c'est dans le futur
    final isFuture = date.isAfter(today);

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFuture
                ? Colors.transparent
                : hasRead
                    ? activeColor
                    : isFrozen
                        ? const Color(0xFF5C6BC0) // Indigo pour les jours frozen
                        : Colors.grey.shade700,
            border: Border.all(
              color: isToday && !hasRead && !isFrozen
                  ? activeColor
                  : Colors.transparent,
              width: 1.5,
              style: isToday && !hasRead && !isFrozen ? BorderStyle.solid : BorderStyle.none,
            ),
          ),
          child: hasRead
              ? Center(
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                )
              : isFrozen
                  ? Center(
                      child: Icon(
                        Icons.ac_unit_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : (isToday && !hasRead)
                      ? Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor,
                            ),
                          ),
                        )
                      : null,
        ),
        if (isToday) ...[
          const SizedBox(height: 1),
          Icon(
            Icons.arrow_drop_up,
            color: activeColor,
            size: 12,
          ),
        ],
      ],
    );
  }
}

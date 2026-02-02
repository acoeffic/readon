// lib/pages/feed/streak_detail_page.dart
// Page détaillée avec calendrier des streaks de lecture

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reading_streak.dart';
import '../../models/streak_freeze.dart';
import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';

class StreakDetailPage extends StatefulWidget {
  final ReadingStreak initialStreak;

  const StreakDetailPage({
    super.key,
    required this.initialStreak,
  });

  @override
  State<StreakDetailPage> createState() => _StreakDetailPageState();
}

class _StreakDetailPageState extends State<StreakDetailPage> {
  final StreakService _streakService = StreakService();
  late ReadingStreak _streak;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _streak = widget.initialStreak;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _streakService.getReadingHistory();
      final streak = await _streakService.getUserStreak();
      setState(() {
        _streak = streak;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getStreakColor() {
    if (_streak.currentStreak >= 30) {
      return AppColors.primary; // Purple
    } else if (_streak.currentStreak >= 14) {
      return const Color(0xFFFF5722); // Deep Orange
    } else if (_streak.currentStreak >= 7) {
      return const Color(0xFFFFC107); // Amber
    } else if (_streak.currentStreak >= 3) {
      return const Color(0xFFFF9800); // Orange
    } else {
      return const Color(0xFF4CAF50); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStreakCard(),
                    const SizedBox(height: 16),
                    _buildFreezeCard(),
                    const SizedBox(height: 24),
                    _buildCurrentMonthCalendar(),
                    const SizedBox(height: 24),
                    _buildMotivationCard(),
                    const SizedBox(height: 24),
                    _buildYearCalendar(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ton streak de lecture',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_streak.currentStreak} jours consécutifs, actif',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    final color = _getStreakColor();
    final progress = _streak.longestStreak > 0
        ? (_streak.currentStreak / _streak.longestStreak).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Statistiques en haut
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_streak.currentStreak}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'jours',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: color,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Streak actuel',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Côté droit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_streak.readDates.length}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'jours au total',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_streak.longestStreak}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'jours au record',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('🏆', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Barre de progression
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_streak.longestStreak}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreezeCard() {
    final freezeStatus = _streak.freezeStatus;
    final isAtRisk = _streak.isAtRisk && _streak.currentStreak > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: freezeStatus?.freezeAvailable == true
            ? const Color(0xFF1A237E).withValues(alpha:0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: freezeStatus?.freezeAvailable == true
              ? const Color(0xFF5C6BC0)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.ac_unit_rounded,
                color: freezeStatus?.freezeAvailable == true
                    ? const Color(0xFF5C6BC0)
                    : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Streak Freeze',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      freezeStatus?.statusMessage ?? 'Freeze disponible',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (freezeStatus?.freezeAvailable == true && isAtRisk)
                ElevatedButton.icon(
                  onPressed: _useFreeze,
                  icon: const Icon(Icons.shield, size: 16),
                  label: const Text('Protéger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                )
              else if (freezeStatus?.freezeAvailable == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0).withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '1 dispo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C6BC0),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Utilisé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
          if (isAtRisk && freezeStatus?.freezeAvailable == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ton streak est en danger ! Utilise ton freeze pour le protéger.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '1 freeze disponible par semaine. Protège ton streak si tu ne peux pas lire un jour.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useFreeze() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.ac_unit_rounded, color: Color(0xFF5C6BC0)),
            SizedBox(width: 12),
            Text('Utiliser le freeze ?'),
          ],
        ),
        content: const Text(
          'Cela protégera ton streak pour hier. Tu ne pourras plus utiliser de freeze cette semaine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _streakService.useFreeze();
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCurrentMonthCalendar() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);

    // Calculer le jour de départ (lundi = 0, dimanche = 6)
    // DateTime.weekday: lundi = 1, dimanche = 7
    // On veut: lundi = 0, dimanche = 6
    int startWeekday = firstDayOfMonth.weekday - 1;

    // Créer les jours du mois
    final List<DateTime?> days = [];

    // Ajouter des jours vides au début
    for (int i = 0; i < startWeekday; i++) {
      days.add(null);
    }

    // Ajouter tous les jours du mois
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(now.year, now.month, day));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Labels des jours
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          // Grille du calendrier
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              if (date == null) {
                return const SizedBox();
              }

              final hasRead = _streak.readDates.any((readDate) {
                return readDate.year == date.year &&
                    readDate.month == date.month &&
                    readDate.day == date.day;
              });

              final isFrozen = _streak.isDayFrozen(date);

              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              final isFuture = date.isAfter(today);

              return _buildCalendarDay(
                date.day,
                hasRead,
                isToday,
                isFuture,
                isFrozen,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(int day, bool hasRead, bool isToday, bool isFuture, bool isFrozen) {
    final color = _getStreakColor();
    const frozenColor = Color(0xFF5C6BC0);

    if (isFuture) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    if (hasRead) {
      return Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      );
    }

    if (isFrozen) {
      return Container(
        decoration: const BoxDecoration(
          color: frozenColor,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.ac_unit_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      );
    }

    if (isToday) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.circle,
            color: color,
            size: 8,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMotivationCard() {
    // Calculer un pourcentage fictif (vous pouvez le calculer réellement)
    final percentage = _streak.readDates.isNotEmpty ? 93 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu as battu $percentage % des lecteurs réguliers.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Bravo! ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Text('🎉', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Continue ta lecture demain pour maintenir ton streak!',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearCalendar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A3D33) : const Color(0xFFB8E6D5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Points indicateurs de mois
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(9, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? const Color(0xFF6DB899)
                      : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5)),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _buildMonthGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // Calculer le jour de départ (lundi = 0, dimanche = 6)
    int startWeekday = firstDayOfMonth.weekday - 1;

    final List<DateTime?> days = [];

    for (int i = 0; i < startWeekday; i++) {
      days.add(null);
    }

    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(now.year, now.month, day));
    }

    return Column(
      children: [
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
              .map((day) => SizedBox(
                    width: 40,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFB8E6D5) : const Color(0xFF2C5F4F),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        // Grille
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            if (date == null) {
              return const SizedBox();
            }

            final hasRead = _streak.readDates.any((readDate) {
              return readDate.year == date.year &&
                  readDate.month == date.month &&
                  readDate.day == date.day;
            });

            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasRead ? const Color(0xFF6DB899) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: hasRead
                      ? Colors.white
                      : (isDark ? const Color(0xFFB8E6D5).withValues(alpha: 0.5) : const Color(0xFF2C5F4F).withValues(alpha: 0.5)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

}

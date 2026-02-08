// lib/pages/feed/flow_detail_page.dart
// Page détaillée avec calendrier des flows de lecture

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/feature_flags.dart';
import '../../models/reading_flow.dart';
import '../../models/flow_freeze.dart';
import '../../pages/profile/upgrade_page.dart';
import '../../providers/subscription_provider.dart';
import '../../services/flow_service.dart';
import '../../theme/app_theme.dart';

class FlowDetailPage extends StatefulWidget {
  final ReadingFlow initialFlow;

  const FlowDetailPage({
    super.key,
    required this.initialFlow,
  });

  @override
  State<FlowDetailPage> createState() => _FlowDetailPageState();
}

class _FlowDetailPageState extends State<FlowDetailPage> {
  final FlowService _flowService = FlowService();
  late ReadingFlow _flow;
  bool _isLoading = true;
  List<DateTime> _months = [];
  int _currentMonthIndex = 0;

  static const _frenchMonths = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    _flow = widget.initialFlow;
    _initMonths();
    _loadData();
  }

  void _initMonths() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    // Trouver la date la plus ancienne parmi readDates et frozenDates
    DateTime? earliest;
    if (_flow.readDates.isNotEmpty) {
      final sortedRead = List<DateTime>.from(_flow.readDates)..sort();
      earliest = sortedRead.first;
    }
    if (_flow.frozenDates.isNotEmpty) {
      final sortedFrozen = List<DateTime>.from(_flow.frozenDates)..sort();
      if (earliest == null || sortedFrozen.first.isBefore(earliest)) {
        earliest = sortedFrozen.first;
      }
    }

    earliest ??= currentMonth;
    final startMonth = DateTime(earliest.year, earliest.month, 1);

    _months = [];
    DateTime m = startMonth;
    while (!m.isAfter(currentMonth)) {
      _months.add(m);
      m = DateTime(m.year, m.month + 1, 1);
    }

    _currentMonthIndex = _months.length - 1;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _flowService.getReadingHistory();
      final flow = await _flowService.getUserFlow();
      setState(() {
        _flow = flow;
        _initMonths();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getFlowColor() {
    if (_flow.currentFlow >= 30) {
      return AppColors.primary; // Purple
    } else if (_flow.currentFlow >= 14) {
      return const Color(0xFFFF5722); // Deep Orange
    } else if (_flow.currentFlow >= 7) {
      return const Color(0xFFFFC107); // Amber
    } else if (_flow.currentFlow >= 3) {
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
                    _buildFlowCard(),
                    const SizedBox(height: 16),
                    _buildFreezeCard(),
                    const SizedBox(height: 24),
                    _buildCalendar(),
                    const SizedBox(height: 24),
                    _buildMotivationCard(),
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
          'Ton flow de lecture',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_flow.currentFlow} jours consécutifs, actif',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowCard() {
    final color = _getFlowColor();
    final progress = _flow.longestFlow > 0
        ? (_flow.currentFlow / _flow.longestFlow).clamp(0.0, 1.0)
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
                          '${_flow.currentFlow}',
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
                          'Flow actuel',
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
                          '${_flow.readDates.length}',
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
                          '${_flow.longestFlow}',
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
                '${_flow.longestFlow}',
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
    final freezeStatus = _flow.freezeStatus;
    final isAtRisk = _flow.isAtRisk && _flow.currentFlow > 0;

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
                      'Flow Freeze',
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
                      'Ton flow est en danger ! Utilise ton freeze pour le protéger.',
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
            '1 freeze disponible par semaine. Protège ton flow si tu ne peux pas lire un jour.',
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
          'Cela protégera ton flow pour hier. Tu ne pourras plus utiliser de freeze cette semaine.',
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
      final result = await _flowService.useFreeze();
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

  void _goToPreviousMonth() {
    if (_currentMonthIndex > 0) {
      setState(() => _currentMonthIndex--);
    }
  }

  void _goToNextMonth() {
    if (_currentMonthIndex < _months.length - 1) {
      setState(() => _currentMonthIndex++);
    }
  }

  Widget _buildCalendar() {
    if (_months.isEmpty) return const SizedBox();

    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final month = _months[_currentMonthIndex];
    final monthLabel = '${_frenchMonths[month.month - 1]} ${month.year}';
    final canGoPrev = _currentMonthIndex > 0;
    final canGoNext = _currentMonthIndex < _months.length - 1;

    final calendarContent = Container(
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
          // Navigation mois
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: isPremium && canGoPrev ? _goToPreviousMonth : null,
                icon: Icon(
                  Icons.chevron_left,
                  color: canGoPrev
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: isPremium && canGoNext ? _goToNextMonth : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: canGoNext
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          // Grille du mois avec swipe
          GestureDetector(
            onHorizontalDragEnd: isPremium
                ? (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 0) {
                      _goToPreviousMonth();
                    } else if (details.primaryVelocity! < 0) {
                      _goToNextMonth();
                    }
                  }
                : null,
            child: _buildMonthGridForDate(month),
          ),
        ],
      ),
    );

    if (isPremium) {
      return calendarContent;
    }

    // Version gratuite : calendrier flouté avec overlay
    return Stack(
      children: [
        // Calendrier flouté
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: calendarContent,
        ),
        // Overlay avec message
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UpgradePage()),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Historique du flow',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Navigue dans tout ton historique de lecture mois par mois',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Débloquer avec Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGridForDate(DateTime month) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    int startWeekday = firstDayOfMonth.weekday - 1;

    final List<DateTime?> days = [];
    for (int i = 0; i < startWeekday; i++) {
      days.add(null);
    }
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(month.year, month.month, day));
    }

    return GridView.builder(
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

        final hasRead = _flow.readDates.any((readDate) {
          return readDate.year == date.year &&
              readDate.month == date.month &&
              readDate.day == date.day;
        });

        final isFrozen = _flow.isDayFrozen(date);

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
    );
  }

  Widget _buildCalendarDay(int day, bool hasRead, bool isToday, bool isFuture, bool isFrozen) {
    final color = _getFlowColor();
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
    final percentage = _flow.readDates.isNotEmpty ? 93 : 0;

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
            'Continue ta lecture demain pour maintenir ton flow!',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

}

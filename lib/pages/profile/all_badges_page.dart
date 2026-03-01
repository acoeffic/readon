// lib/pages/profile/all_badges_page.dart
// Page complète affichant tous les badges par catégorie

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/badges_service.dart';
import '../../providers/subscription_provider.dart';
import '../../pages/profile/upgrade_page.dart';
import '../../theme/app_theme.dart';
import '../../features/badges/widgets/first_book_badge_painter.dart';

class AllBadgesPage extends StatefulWidget {
  const AllBadgesPage({super.key});

  @override
  State<AllBadgesPage> createState() => _AllBadgesPageState();
}

class _AllBadgesPageState extends State<AllBadgesPage> {
  final badgesService = BadgesService();
  List<UserBadge> _allBadges = [];
  bool _isLoading = true;
  String _selectedMainFilter = 'all'; // 'all', 'unlocked', 'locked'
  final Set<String> _selectedSubFilters = {}; // 'premium', 'secret'

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    try {
      final badges = await badgesService.getUserBadges();
      setState(() {
        _allBadges = badges;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur _loadBadges: $e');
      setState(() => _isLoading = false);
    }
  }

  List<UserBadge> _getFilteredBadges() {
    List<UserBadge> filtered = _allBadges;

    // Main filter
    switch (_selectedMainFilter) {
      case 'unlocked':
        filtered = filtered.where((b) => b.isUnlocked).toList();
        break;
      case 'locked':
        filtered = filtered.where((b) => !b.isUnlocked).toList();
        break;
    }

    // Sub filters (cumulative)
    if (_selectedSubFilters.contains('premium')) {
      filtered = filtered.where((b) => b.isPremium).toList();
    }
    if (_selectedSubFilters.contains('secret')) {
      filtered = filtered.where((b) => b.isSecret).toList();
    }

    return filtered;
  }

  Map<String, List<UserBadge>> _getBadgesByCategory() {
    final filtered = _getFilteredBadges();
    final Map<String, List<UserBadge>> categories = {};

    // Ordre des catégories
    const categoryOrder = [
      'books_completed',
      'reading_time',
      'streak',
      'goals',
      'social',
      'genres',
      'engagement',
      'animated',
      'secret',
      'style',
      'monthly',
      'yearly',
      'anniversary',
      'annual_books',
      'occasion',
    ];

    for (var category in categoryOrder) {
      final badges = filtered.where((b) => b.category == category).toList();
      if (badges.isNotEmpty) {
        categories[category] = badges;
      }
    }

    // Ajouter les catégories non listées
    for (var badge in filtered) {
      if (!categoryOrder.contains(badge.category)) {
        categories.putIfAbsent(badge.category, () => []);
        if (!categories[badge.category]!.any((b) => b.id == badge.id)) {
          categories[badge.category]!.add(badge);
        }
      }
    }

    return categories;
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'books_completed':
        return 'Livres terminés';
      case 'reading_time':
        return 'Temps de lecture';
      case 'streak':
        return 'Flows';
      case 'goals':
        return 'Objectifs';
      case 'social':
        return 'Social';
      case 'genres':
        return 'Exploration & Genres';
      case 'engagement':
        return 'Engagement';
      case 'animated':
        return 'Badges animés';
      case 'secret':
        return 'Badges secrets';
      case 'style':
        return 'Style & Personnalité';
      case 'monthly':
        return 'Challenges mensuels';
      case 'yearly':
        return 'Année & Récap';
      case 'anniversary':
        return 'Anniversaire';
      case 'annual_books':
        return 'Livres annuels';
      case 'occasion':
        return 'Occasions spéciales';
      case 'trophy':
        return 'Trophées';
      default:
        return category;
    }
  }

  UserBadge? _getNextBadge() {
    // Trouver le prochain badge à débloquer (le plus proche d'être complété)
    final lockedBadges = _allBadges
        .where((b) => !b.isUnlocked && !b.isSecret && !b.isPremium)
        .toList();

    if (lockedBadges.isEmpty) return null;

    // Trier par progression décroissante
    lockedBadges.sort(
        (a, b) => b.progressPercentage.compareTo(a.progressPercentage));

    return lockedBadges.first;
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Comment ça marche ?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
                '📖', 'Lisez des livres et complétez des sessions pour débloquer des badges'),
            const SizedBox(height: 12),
            _buildHelpItem(
                '🔒', 'Les badges verrouillés montrent votre progression'),
            const SizedBox(height: 12),
            _buildHelpItem(
                '👑', 'Les badges Premium sont exclusifs aux abonnés'),
            const SizedBox(height: 12),
            _buildHelpItem(
                '🕵️', 'Les badges secrets ont des conditions cachées'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris !'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final unlockedCount = _allBadges.where((b) => b.isUnlocked).length;
    final totalCount = _allBadges.length;
    final percentage =
        totalCount > 0 ? ((unlockedCount / totalCount) * 100).round() : 0;
    final nextBadge = _getNextBadge();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes badges'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            onPressed: _showHelpDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary card
                  _SummaryCard(
                    unlockedCount: unlockedCount,
                    totalCount: totalCount,
                    percentage: percentage,
                    nextBadge: nextBadge,
                  ),

                  const SizedBox(height: 12),

                  // Premium banner (si free user)
                  if (!isPremium) ...[
                    _PremiumBanner(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UpgradePage()),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Main filter tabs
                  _MainFilterTabs(
                    selectedFilter: _selectedMainFilter,
                    onFilterChanged: (filter) =>
                        setState(() => _selectedMainFilter = filter),
                  ),

                  const SizedBox(height: 12),

                  // Sub filter chips
                  _SubFilterChips(
                    selectedFilters: _selectedSubFilters,
                    onFilterToggled: (filter) {
                      setState(() {
                        if (_selectedSubFilters.contains(filter)) {
                          _selectedSubFilters.remove(filter);
                        } else {
                          _selectedSubFilters.add(filter);
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Badge sections
                  if (_getFilteredBadges().isEmpty)
                    _EmptyState(filter: _selectedMainFilter)
                  else
                    ..._getBadgesByCategory().entries.map((entry) {
                      return _CategorySection(
                        title: _getCategoryTitle(entry.key),
                        badges: entry.value,
                        isPremiumUser: isPremium,
                      );
                    }),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// Summary card avec progression circulaire
class _SummaryCard extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;
  final int percentage;
  final UserBadge? nextBadge;

  const _SummaryCard({
    required this.unlockedCount,
    required this.totalCount,
    required this.percentage,
    this.nextBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Left side - text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$unlockedCount badges débloqués',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      TextSpan(
                        text: ' sur $totalCount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (nextBadge != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Prochain : ${nextBadge!.name} (${nextBadge!.progress}/${nextBadge!.requirement})',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? unlockedCount / totalCount : 0,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Right side - circular progress
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: totalCount > 0 ? unlockedCount / totalCount : 0,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                progressColor: AppColors.primary,
                strokeWidth: 8,
              ),
              child: Center(
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter pour le cercle de progression
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
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

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Premium banner
class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Débloque des badges exclusifs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Badges Premium + défis secrets',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👑', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'Voir Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Main filter tabs (Tous, Débloqués, Verrouillés)
class _MainFilterTabs extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _MainFilterTabs({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Tous',
            isSelected: selectedFilter == 'all',
            onTap: () => onFilterChanged('all'),
          ),
          _TabButton(
            label: 'Débloqués',
            isSelected: selectedFilter == 'unlocked',
            onTap: () => onFilterChanged('unlocked'),
          ),
          _TabButton(
            label: 'Verrouillés',
            isSelected: selectedFilter == 'locked',
            onTap: () => onFilterChanged('locked'),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : unselectedColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Sub filter chips (Premium, Secrets)
class _SubFilterChips extends StatelessWidget {
  final Set<String> selectedFilters;
  final ValueChanged<String> onFilterToggled;

  const _SubFilterChips({
    required this.selectedFilters,
    required this.onFilterToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          emoji: '👑',
          label: 'Premium',
          isSelected: selectedFilters.contains('premium'),
          onTap: () => onFilterToggled('premium'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          emoji: '🕵️',
          label: 'Secrets',
          isSelected: selectedFilters.contains('secret'),
          onTap: () => onFilterToggled('secret'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final unselectedTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : unselectedTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  final String filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    String message;
    switch (filter) {
      case 'unlocked':
        message = 'Aucun badge débloqué pour le moment.\nContinuez à lire pour en débloquer !';
        break;
      case 'locked':
        message = 'Tous les badges sont débloqués.\nFélicitations !';
        break;
      default:
        message = 'Aucun badge disponible.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Category section
class _CategorySection extends StatelessWidget {
  final String title;
  final List<UserBadge> badges;
  final bool isPremiumUser;

  const _CategorySection({
    required this.title,
    required this.badges,
    required this.isPremiumUser,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$title · ${badges.length} badges',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            return _BadgeCard(
              badge: badges[index],
              isPremiumUser: isPremiumUser,
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// Badge card
class _BadgeCard extends StatelessWidget {
  final UserBadge badge;
  final bool isPremiumUser;

  const _BadgeCard({required this.badge, required this.isPremiumUser});

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  bool get _isPremiumLocked => badge.isPremium && !isPremiumUser;
  bool get _isSecretHidden => badge.isSecret && !badge.isUnlocked;
  bool get _isAnniversaryHidden => badge.category == 'anniversary' && !badge.isUnlocked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _hexToColor(badge.color);
    final isLocked = !badge.isUnlocked;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final lockedTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: () => _showBadgeDetails(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: badge.isPremium && !badge.isUnlocked
              ? Border.all(
                  color: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
                  width: 2,
                )
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon
            ClipOval(
              child: ImageFiltered(
                imageFilter: _isAnniversaryHidden
                    ? ImageFilter.blur(sigmaX: 6, sigmaY: 6)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: isFirstBookBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? FirstBookBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ApprenticeReaderBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isConfirmedReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ConfirmedReaderBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isBibliophileBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? BibliophileBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOneHourMagicBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OneHourMagicBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isSundayReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? SundayReaderBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isPassionateBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? PassionateBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isCenturionBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? CenturionBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isMarathonBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? MarathonBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isHalfMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? HalfMillenniumBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? MillenniumBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isClubFounderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ClubFounderBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isClubLeaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ClubLeaderBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isResidentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ResidentBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isHabitueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? HabitueBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isPilierBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? PilierBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isMonumentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? MonumentBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isAnnualOnePerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualOnePerMonthBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isAnnualTwoPerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualTwoPerMonthBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isAnnualOnePerWeekBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualOnePerWeekBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isAnnualCentenaireBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualCentenaireBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionBastilleDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionBastilleDayBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionChristmasBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionChristmasBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionFeteMusiqueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionFeteMusiqueBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionHalloweenBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionHalloweenBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionSummerReadBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionSummerReadBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionValentineBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionValentineBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionNyeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionNyeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionLabourDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionLabourDayBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionWorldBookDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionWorldBookDayBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionNewYearBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionNewYearBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionEasterBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionEasterBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isOccasionAprilFoolsBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionAprilFoolsBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreSfApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenrePolarApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenrePolarAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenrePolarMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenrePolarLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreSfApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreSfAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreSfMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreSfLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreRomanceApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreRomanceAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreRomanceMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreRomanceLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHorreurApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHorreurAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHorreurMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHorreurLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreBioApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreBioAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreBioMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreBioLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHistoireApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHistoireAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHistoireMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreHistoireLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoApprentiBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoAdepteBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoMaitreBadge(size: 80, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoLegendeBadge(size: 80, isLocked: !badge.isUnlocked)
                    : Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isSecretHidden
                              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                              : isLocked
                                  ? color.withValues(alpha: isDark ? 0.2 : 0.1)
                                  : color.withValues(alpha: isDark ? 0.25 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _isSecretHidden
                              ? Text(
                                  '?',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: secondaryTextColor,
                                  ),
                                )
                              : Text(
                                  badge.icon,
                                  style: const TextStyle(fontSize: 40),
                                ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Badge name
            ImageFiltered(
              imageFilter: _isAnniversaryHidden
                  ? ImageFilter.blur(sigmaX: 4, sigmaY: 4)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Text(
                _isSecretHidden ? '???' : badge.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLocked ? lockedTextColor : textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 4),

            // Category / subtitle
            Text(
              _isSecretHidden
                  ? 'Badge secret'
                  : _getCategoryLabel(badge.category),
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),

            const SizedBox(height: 8),

            // Status row
            if (badge.isUnlocked) ...[
              // Débloqué
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Débloqué',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Full progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ] else if (badge.isPremium && !isPremiumUser) ...[
              // Premium badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.shade900.withValues(alpha: 0.3)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_isSecretHidden) ...[
              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    '${badge.progress}/${badge.requirement}',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: badge.progressPercentage,
                  backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.6)),
                  minHeight: 6,
                ),
              ),
            ] else ...[
              // Secret hidden - show "Progress" text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'books_completed':
        return 'Livres terminés';
      case 'reading_time':
        return 'Temps de lecture';
      case 'streak':
        return 'Flow';
      case 'goals':
        return 'Objectifs';
      case 'social':
        return 'Social';
      case 'genres':
        return 'Genres';
      case 'engagement':
        return 'Engagement';
      case 'animated':
        return 'Animé';
      case 'secret':
        return 'Secret';
      case 'style':
        return 'Style';
      case 'monthly':
        return 'Challenge mensuel';
      case 'yearly':
        return 'Annuel';
      case 'anniversary':
        return 'Anniversaire';
      case 'annual_books':
        return 'Livres annuels';
      case 'occasion':
        return 'Occasion';
      default:
        return category;
    }
  }

  void _showBadgeDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _hexToColor(badge.color);
    final secondaryTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium indicator
            if (badge.isPremium) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.shade900.withValues(alpha: 0.3)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Badge Premium',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Badge icon
            ClipOval(
              child: ImageFiltered(
                imageFilter: _isAnniversaryHidden
                    ? ImageFilter.blur(sigmaX: 8, sigmaY: 8)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: isFirstBookBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? FirstBookBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isApprenticeReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ApprenticeReaderBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isConfirmedReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ConfirmedReaderBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isBibliophileBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? BibliophileBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOneHourMagicBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OneHourMagicBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isSundayReaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? SundayReaderBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isPassionateBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? PassionateBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isCenturionBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? CenturionBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isMarathonBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? MarathonBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isHalfMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? HalfMillenniumBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isMillenniumBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? MillenniumBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isClubFounderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ClubFounderBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isClubLeaderBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ClubLeaderBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isResidentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? ResidentBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isHabitueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? HabitueBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isPilierBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? PilierBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isMonumentBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? MonumentBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isAnnualOnePerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualOnePerMonthBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isAnnualTwoPerMonthBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualTwoPerMonthBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isAnnualOnePerWeekBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualOnePerWeekBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isAnnualCentenaireBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? AnnualCentenaireBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionBastilleDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionBastilleDayBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionChristmasBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionChristmasBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionFeteMusiqueBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionFeteMusiqueBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionHalloweenBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionHalloweenBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionSummerReadBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionSummerReadBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionValentineBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionValentineBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionNyeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionNyeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionLabourDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionLabourDayBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionWorldBookDayBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionWorldBookDayBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionNewYearBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionNewYearBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionEasterBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionEasterBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isOccasionAprilFoolsBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? OccasionAprilFoolsBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreSfApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenrePolarApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenrePolarAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenrePolarMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenrePolarLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenrePolarLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreSfApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreSfAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreSfMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreSfLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreSfLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreRomanceApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreRomanceAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreRomanceMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreRomanceLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreRomanceLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHorreurApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHorreurAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHorreurMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHorreurLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHorreurLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreBioApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreBioAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreBioMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreBioLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreBioLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHistoireApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHistoireAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHistoireMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreHistoireLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreHistoireLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoApprentiBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoApprentiBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoAdepteBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoAdepteBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoMaitreBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoMaitreBadge(size: 120, isLocked: !badge.isUnlocked)
                    : isGenreDevpersoLegendeBadge(id: badge.id, category: badge.category, requirement: badge.requirement)
                    ? GenreDevpersoLegendeBadge(size: 120, isLocked: !badge.isUnlocked)
                    : Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _isSecretHidden
                              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                              : badge.isUnlocked
                                  ? color.withValues(alpha: 0.2)
                                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isSecretHidden
                                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                                : badge.isUnlocked
                                    ? color
                                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: _isSecretHidden
                              ? Text(
                                  '?',
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: secondaryTextColor,
                                  ),
                                )
                              : Text(
                                  badge.icon,
                                  style: const TextStyle(fontSize: 56),
                                ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Badge name
            ImageFiltered(
              imageFilter: _isAnniversaryHidden
                  ? ImageFilter.blur(sigmaX: 5, sigmaY: 5)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Text(
                _isSecretHidden ? '??? Badge Secret' : badge.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            ImageFiltered(
              imageFilter: _isAnniversaryHidden
                  ? ImageFilter.blur(sigmaX: 4, sigmaY: 4)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Text(
                _isSecretHidden
                    ? 'Condition cachée... Continuez à lire pour le découvrir !'
                    : badge.description,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  fontStyle: _isSecretHidden ? FontStyle.italic : FontStyle.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            if (badge.isUnlocked) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.green.shade700 : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade500, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Débloqué',
                      style: TextStyle(
                        color: isDark ? Colors.green.shade400 : Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge.unlockedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Le ${_formatDate(badge.unlockedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ] else if (_isPremiumLocked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.shade900.withValues(alpha: 0.3)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      'Badge Premium',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Passez à Premium pour débloquer',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (!_isSecretHidden) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Progression',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: badge.progressPercentage,
                        backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      badge.progressText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_isPremiumLocked)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradePage()),
                );
              },
              child: Text(
                'Passer Premium',
                style: TextStyle(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Fermer',
              style: TextStyle(
                color: secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sep',
      'oct',
      'nov',
      'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

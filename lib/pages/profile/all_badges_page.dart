// lib/pages/profile/all_badges_page.dart
// Page complète affichant tous les badges par catégorie

import 'package:flutter/material.dart';
import '../../services/badges_service.dart';
import '../../theme/app_theme.dart';

class AllBadgesPage extends StatefulWidget {
  const AllBadgesPage({super.key});

  @override
  State<AllBadgesPage> createState() => _AllBadgesPageState();
}

class _AllBadgesPageState extends State<AllBadgesPage> {
  final badgesService = BadgesService();
  List<UserBadge> _allBadges = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'unlocked', 'locked'

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
      print('Erreur _loadBadges: $e');
      setState(() => _isLoading = false);
    }
  }

  List<UserBadge> _getFilteredBadges() {
    switch (_selectedFilter) {
      case 'unlocked':
        return _allBadges.where((b) => b.isUnlocked).toList();
      case 'locked':
        return _allBadges.where((b) => !b.isUnlocked).toList();
      default:
        return _allBadges;
    }
  }

  Map<String, List<UserBadge>> _getBadgesByCategory() {
    final filtered = _getFilteredBadges();
    final Map<String, List<UserBadge>> categories = {};
    
    for (var badge in filtered) {
      if (!categories.containsKey(badge.category)) {
        categories[badge.category] = [];
      }
      categories[badge.category]!.add(badge);
    }
    
    return categories;
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'books_completed':
        return '📚 Livres Terminés';
      case 'reading_times':
        return '🕐 Horaires de Lecture';
      case 'reading_speed':
        return '🚀 Vitesse de Lecture';
      case 'reading_duration':
        return '⏱️ Durée de Lecture';
      case 'trophy':
        return '🏆 Trophées';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _allBadges.where((b) => b.isUnlocked).length;
    final totalCount = _allBadges.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes Badges'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header avec stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$unlockedCount / $totalCount',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Badges débloqués',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: totalCount > 0 ? unlockedCount / totalCount : 0,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),

                // Filtres
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        isSelected: _selectedFilter == 'all',
                        onTap: () => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Débloqués',
                        isSelected: _selectedFilter == 'unlocked',
                        onTap: () => setState(() => _selectedFilter = 'unlocked'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Verrouillés',
                        isSelected: _selectedFilter == 'locked',
                        onTap: () => setState(() => _selectedFilter = 'locked'),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Liste des badges par catégorie
                Expanded(
                  child: _getFilteredBadges().isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.emoji_events_outlined,
                                   size: 64,
                                   color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'unlocked'
                                    ? 'Aucun badge débloqué'
                                    : 'Aucun badge',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _getBadgesByCategory().entries.map((entry) {
                            return _CategorySection(
                              title: _getCategoryTitle(entry.key),
                              badges: entry.value,
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final List<UserBadge> badges;

  const _CategorySection({
    required this.title,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            return _BadgeCard(badge: badges[index]);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final UserBadge badge;

  const _BadgeCard({required this.badge});

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(badge.color);
    final isLocked = !badge.isUnlocked;

    return GestureDetector(
      onTap: () => _showBadgeDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLocked ? Theme.of(context).dividerColor : color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: isLocked
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isLocked
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badge.icon,
                  style: TextStyle(
                    fontSize: 36,
                    color: isLocked ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4) : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Badge name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                badge.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isLocked
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Progress bar (si verrouillé)
            if (isLocked) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: badge.progressPercentage,
                        backgroundColor: Theme.of(context).dividerColor,
                        valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${badge.progress}/${badge.requirement}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Débloqué badge
            if (!isLocked) ...[
              const SizedBox(height: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context) {
    final color = _hexToColor(badge.color);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: badge.isUnlocked
                    ? color.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: badge.isUnlocked ? color : Theme.of(context).dividerColor,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  badge.icon,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (badge.isUnlocked) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Débloqué',
                      style: TextStyle(
                        color: Colors.green.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge.unlockedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Le ${_formatDate(badge.unlockedAt!)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Progression',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: badge.progressPercentage,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.progressText,
                      style: TextStyle(
                        fontSize: 14,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

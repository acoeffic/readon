// lib/features/badges/widgets/books_badge_debug_page.dart
// Page de test temporaire pour les badges livres terminés — à supprimer avant la prod

import 'package:flutter/material.dart';
import '../../../services/badges_service.dart';
import '../../../widgets/badge_unlocked_dialog.dart';
import 'first_book_badge_painter.dart';

/// Les 8 badges livres terminés avec leurs métadonnées.
class _BookBadgeData {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int requirement;
  final String tier;
  final String color;
  final bool isPremium;

  const _BookBadgeData({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requirement,
    required this.tier,
    required this.color,
    this.isPremium = false,
  });
}

const _allSocialBadges = [
  _BookBadgeData(
    id: 'social_club_founder',
    name: 'Fondateur de Club',
    description: 'Créer un club de lecture',
    icon: '🏠',
    requirement: 1,
    tier: 'gold',
    color: '#FF6B00',
    isPremium: true,
  ),
  _BookBadgeData(
    id: 'social_club_leader',
    name: 'Leader',
    description: 'Club avec 10+ membres',
    icon: '👥',
    requirement: 10,
    tier: 'platinum',
    color: '#FF6B00',
    isPremium: true,
  ),
];

const _allSeniorityBadges = [
  _BookBadgeData(
    id: 'seniority_1y',
    name: 'Résident',
    description: '1 an sur LexDay',
    icon: '🏠',
    requirement: 365,
    tier: 'gold',
    color: '#8D6E63',
  ),
  _BookBadgeData(
    id: 'seniority_2y',
    name: 'Habitué',
    description: 'Lexsta, c\'est chez toi',
    icon: '🏡',
    requirement: 730,
    tier: 'platinum',
    color: '#6D4C41',
  ),
  _BookBadgeData(
    id: 'seniority_3y',
    name: 'Pilier',
    description: 'La communauté te connaît',
    icon: '🏛️',
    requirement: 1095,
    tier: 'diamond',
    color: '#4E342E',
  ),
  _BookBadgeData(
    id: 'seniority_5y',
    name: 'Monument',
    description: 'Tu étais là depuis le début',
    icon: '🗿',
    requirement: 1825,
    tier: 'legendary',
    color: '#3E2723',
  ),
];

const _allTimeBadges = [
  _BookBadgeData(
    id: 'time_1h',
    name: 'Une Heure de Magie',
    description: '1h de lecture cumulée',
    icon: '⌛',
    requirement: 60,
    tier: 'bronze',
    color: '#1E88E5',
  ),
  _BookBadgeData(
    id: 'time_10h',
    name: 'Lecteur du Dimanche',
    description: '10h de lecture cumulées',
    icon: '☕',
    requirement: 600,
    tier: 'silver',
    color: '#1976D2',
  ),
  _BookBadgeData(
    id: 'time_50h',
    name: 'Passionné',
    description: '50h de lecture cumulées',
    icon: '💜',
    requirement: 3000,
    tier: 'gold',
    color: '#1565C0',
  ),
  _BookBadgeData(
    id: 'time_100h',
    name: 'Centurion',
    description: '100h de lecture cumulées',
    icon: '🏆',
    requirement: 6000,
    tier: 'platinum',
    color: '#0D47A1',
  ),
  _BookBadgeData(
    id: 'time_250h',
    name: 'Marathonien',
    description: '250h de lecture',
    icon: '🏃',
    requirement: 15000,
    tier: 'diamond',
    color: '#FFD700',
    isPremium: true,
  ),
  _BookBadgeData(
    id: 'time_500h',
    name: 'Demi-Millénaire',
    description: '500h de lecture',
    icon: '⚡',
    requirement: 30000,
    tier: 'legendary',
    color: '#FFC107',
    isPremium: true,
  ),
  _BookBadgeData(
    id: 'time_1000h',
    name: 'Millénaire',
    description: '1000h de lecture',
    icon: '🌟',
    requirement: 60000,
    tier: 'mythic',
    color: '#FF9800',
    isPremium: true,
  ),
];

const _allBookBadges = [
  _BookBadgeData(
    id: 'books_1',
    name: 'Premier Chapitre',
    description: 'Terminer son 1er livre',
    icon: '📖',
    requirement: 1,
    tier: 'bronze',
    color: '#4CAF50',
  ),
  _BookBadgeData(
    id: 'books_5',
    name: 'Apprenti Lecteur',
    description: '5 livres terminés',
    icon: '📚',
    requirement: 5,
    tier: 'silver',
    color: '#66BB6A',
  ),
  _BookBadgeData(
    id: 'books_10',
    name: 'Lecteur Confirmé',
    description: '10 livres terminés',
    icon: '📚',
    requirement: 10,
    tier: 'gold',
    color: '#43A047',
  ),
  _BookBadgeData(
    id: 'books_25',
    name: 'Bibliophile',
    description: '25 livres terminés',
    icon: '🏛️',
    requirement: 25,
    tier: 'platinum',
    color: '#388E3C',
  ),
  _BookBadgeData(
    id: 'books_50',
    name: 'Dévoreur de Pages',
    description: '50 livres terminés',
    icon: '🔥',
    requirement: 50,
    tier: 'diamond',
    color: '#2E7D32',
  ),
  _BookBadgeData(
    id: 'books_100',
    name: 'Centenaire',
    description: '100 livres terminés',
    icon: '💯',
    requirement: 100,
    tier: 'legendary',
    color: '#FFD700',
    isPremium: true,
  ),
  _BookBadgeData(
    id: 'books_200',
    name: 'Légende Littéraire',
    description: '200 livres terminés',
    icon: '👑',
    requirement: 200,
    tier: 'mythic',
    color: '#FFC107',
    isPremium: true,
  ),
  _BookBadgeData(
    id: 'books_500',
    name: 'Bibliothèque Vivante',
    description: '500 livres terminés',
    icon: '🏛️',
    requirement: 500,
    tier: 'transcendent',
    color: '#FF9800',
    isPremium: true,
  ),
];

class BooksBadgeDebugPage extends StatefulWidget {
  const BooksBadgeDebugPage({super.key});

  @override
  State<BooksBadgeDebugPage> createState() => _BooksBadgeDebugPageState();
}

class _BooksBadgeDebugPageState extends State<BooksBadgeDebugPage> {
  final _badgesService = BadgesService();
  int _completedBooks = 0;
  bool _loading = true;
  bool _showLocked = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final count = await _badgesService.getCompletedBooksCount();
    if (mounted) {
      setState(() {
        _completedBooks = count;
        _loading = false;
      });
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'platinum':
        return const Color(0xFFE5E4E2);
      case 'diamond':
        return const Color(0xFFB9F2FF);
      case 'legendary':
        return const Color(0xFFFF6B00);
      case 'mythic':
        return const Color(0xFFFF0080);
      case 'transcendent':
        return const Color(0xFF8B00FF);
      default:
        return Colors.grey;
    }
  }

  Widget _buildBadgeIcon(_BookBadgeData data, {required double size, required bool locked}) {
    if (isFirstBookBadge(id: data.id, category: 'books_completed', requirement: data.requirement)) {
      return FirstBookBadge(size: size, isLocked: locked);
    }
    if (isApprenticeReaderBadge(id: data.id, category: 'books_completed', requirement: data.requirement)) {
      return ApprenticeReaderBadge(size: size, isLocked: locked);
    }
    if (isConfirmedReaderBadge(id: data.id, category: 'books_completed', requirement: data.requirement)) {
      return ConfirmedReaderBadge(size: size, isLocked: locked);
    }
    if (isBibliophileBadge(id: data.id, category: 'books_completed', requirement: data.requirement)) {
      return BibliophileBadge(size: size, isLocked: locked);
    }

    if (isOneHourMagicBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return OneHourMagicBadge(size: size, isLocked: locked);
    }
    if (isSundayReaderBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return SundayReaderBadge(size: size, isLocked: locked);
    }
    if (isPassionateBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return PassionateBadge(size: size, isLocked: locked);
    }
    if (isCenturionBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return CenturionBadge(size: size, isLocked: locked);
    }
    if (isMarathonBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return MarathonBadge(size: size, isLocked: locked);
    }
    if (isHalfMillenniumBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return HalfMillenniumBadge(size: size, isLocked: locked);
    }
    if (isMillenniumBadge(id: data.id, category: 'reading_time', requirement: data.requirement)) {
      return MillenniumBadge(size: size, isLocked: locked);
    }

    if (isClubFounderBadge(id: data.id, category: 'social', requirement: data.requirement)) {
      return ClubFounderBadge(size: size, isLocked: locked);
    }
    if (isClubLeaderBadge(id: data.id, category: 'social', requirement: data.requirement)) {
      return ClubLeaderBadge(size: size, isLocked: locked);
    }

    if (isResidentBadge(id: data.id, category: 'engagement', requirement: data.requirement)) {
      return ResidentBadge(size: size, isLocked: locked);
    }
    if (isHabitueBadge(id: data.id, category: 'engagement', requirement: data.requirement)) {
      return HabitueBadge(size: size, isLocked: locked);
    }
    if (isPilierBadge(id: data.id, category: 'engagement', requirement: data.requirement)) {
      return PilierBadge(size: size, isLocked: locked);
    }
    if (isMonumentBadge(id: data.id, category: 'engagement', requirement: data.requirement)) {
      return MonumentBadge(size: size, isLocked: locked);
    }

    // Fallback : emoji dans un cercle
    final color = _hexToColor(data.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.2),
        border: Border.all(
          color: locked ? Colors.grey : color,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          data.icon,
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }

  void _showUnlockDialog(_BookBadgeData data, {String category = 'books_completed'}) {
    final badge = UserBadge(
      id: data.id,
      name: data.name,
      description: data.description,
      icon: data.icon,
      category: category,
      requirement: data.requirement,
      color: data.color,
      progress: data.requirement,
      isUnlocked: true,
      isPremium: data.isPremium,
      tier: data.tier,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BadgeUnlockedDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Badges Livres'),
        actions: [
          IconButton(
            icon: Icon(_showLocked ? Icons.lock_open : Icons.lock),
            tooltip: _showLocked ? 'Voir débloqués' : 'Voir verrouillés',
            onPressed: () => setState(() => _showLocked = !_showLocked),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header info
                Text(
                  'Appuie sur un badge pour lancer le dialogue de déblocage.\n'
                  'Toggle le cadenas pour voir locked/unlocked.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),

                // Stats réelles
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('📚', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_completedBooks livres terminés',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tes vraies données',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Mode toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _showLocked
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showLocked ? Icons.lock : Icons.lock_open,
                        size: 18,
                        color: _showLocked ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showLocked ? 'Mode verrouillé' : 'Mode débloqué',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _showLocked ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Grid de badges
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _allBookBadges.length,
                  itemBuilder: (context, index) {
                    final data = _allBookBadges[index];
                    final tierCol = _tierColor(data.tier);
                    final isUnlocked = !_showLocked && _completedBooks >= data.requirement;

                    return GestureDetector(
                      onTap: () => _showUnlockDialog(data),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showLocked
                                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                                : tierCol.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: !_showLocked && isUnlocked
                              ? [
                                  BoxShadow(
                                    color: tierCol.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tier label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tierCol.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tierCol.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                data.tier.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tierCol,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Badge icon
                            _buildBadgeIcon(
                              data,
                              size: 72,
                              locked: _showLocked,
                            ),
                            const SizedBox(height: 10),

                            // Name
                            Text(
                              data.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _showLocked
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Requirement + premium
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${data.requirement} livre${data.requirement > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (data.isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Text('👑', style: TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Play icon
                            Icon(
                              Icons.play_circle_outline,
                              size: 20,
                              color: tierCol.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Titre section temps de lecture
                Text(
                  'Badges Temps de Lecture',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Grid de badges temps
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _allTimeBadges.length,
                  itemBuilder: (context, index) {
                    final data = _allTimeBadges[index];
                    final tierCol = _tierColor(data.tier);

                    return GestureDetector(
                      onTap: () => _showUnlockDialog(data, category: 'reading_time'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showLocked
                                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                                : tierCol.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tier label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tierCol.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tierCol.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                data.tier.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tierCol,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Badge icon
                            _buildBadgeIcon(
                              data,
                              size: 72,
                              locked: _showLocked,
                            ),
                            const SizedBox(height: 10),

                            // Name
                            Text(
                              data.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _showLocked
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Requirement + premium
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${data.requirement} min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (data.isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Text('👑', style: TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Play icon
                            Icon(
                              Icons.play_circle_outline,
                              size: 20,
                              color: tierCol.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Titre section social
                Text(
                  'Badges Social',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Grid de badges social
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _allSocialBadges.length,
                  itemBuilder: (context, index) {
                    final data = _allSocialBadges[index];
                    final tierCol = _tierColor(data.tier);

                    return GestureDetector(
                      onTap: () => _showUnlockDialog(data, category: 'social'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showLocked
                                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                                : tierCol.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tier label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tierCol.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tierCol.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                data.tier.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tierCol,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Badge icon
                            _buildBadgeIcon(
                              data,
                              size: 72,
                              locked: _showLocked,
                            ),
                            const SizedBox(height: 10),

                            // Name
                            Text(
                              data.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _showLocked
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Requirement + premium
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (data.isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Text('👑', style: TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Play icon
                            Icon(
                              Icons.play_circle_outline,
                              size: 20,
                              color: tierCol.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Titre section ancienneté
                Text(
                  'Badges Ancienneté',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Grid de badges ancienneté
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _allSeniorityBadges.length,
                  itemBuilder: (context, index) {
                    final data = _allSeniorityBadges[index];
                    final tierCol = _tierColor(data.tier);

                    return GestureDetector(
                      onTap: () => _showUnlockDialog(data, category: 'engagement'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showLocked
                                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                                : tierCol.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tier label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tierCol.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tierCol.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                data.tier.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tierCol,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Badge icon
                            _buildBadgeIcon(
                              data,
                              size: 72,
                              locked: _showLocked,
                            ),
                            const SizedBox(height: 10),

                            // Name
                            Text(
                              data.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _showLocked
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Requirement
                            Text(
                              data.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Play icon
                            Icon(
                              Icons.play_circle_outline,
                              size: 20,
                              color: tierCol.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

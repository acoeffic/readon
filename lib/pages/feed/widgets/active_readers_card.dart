// pages/feed/widgets/active_readers_card.dart
// Carousel horizontal des lecteurs actuellement en session (profils publics)

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../widgets/cached_profile_avatar.dart';

class ActiveReadersCard extends StatelessWidget {
  final List<Map<String, dynamic>> readers;
  final void Function(Map<String, dynamic> reader)? onReaderTap;

  const ActiveReadersCard({super.key, required this.readers, this.onReaderTap});

  @override
  Widget build(BuildContext context) {
    if (readers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _PulsingDot(),
            const SizedBox(width: 8),
            Text(
              'En train de lire',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                'EN DIRECT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4CAF50),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: readers.length,
            itemBuilder: (context, index) {
              final reader = readers[index];
              return _ActiveReaderItem(
                displayName: reader['display_name'] as String? ?? 'Un lecteur',
                avatarUrl: reader['avatar_url'] as String?,
                bookTitle: reader['book_title'] as String? ?? '',
                bookAuthor: reader['book_author'] as String?,
                bookCover: reader['book_cover'] as String?,
                startTime: reader['start_time'] as String?,
                onTap: onReaderTap != null ? () => onReaderTap!(reader) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActiveReaderItem extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookCover;
  final String? startTime;
  final VoidCallback? onTap;

  const _ActiveReaderItem({
    required this.displayName,
    this.avatarUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.bookCover,
    this.startTime,
    this.onTap,
  });

  String _getSinceText() {
    if (startTime == null) return 'En cours';
    try {
      final start = DateTime.parse(startTime!);
      final minutes = DateTime.now().difference(start).inMinutes;
      if (minutes < 1) return 'À l\'instant';
      if (minutes < 60) return 'Depuis ${minutes}min';
      final hours = (minutes / 60).floor();
      return 'Depuis ${hours}h';
    } catch (_) {
      return 'En cours';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Couverture du livre
                Stack(
                  children: [
                    CachedBookCover(
                      imageUrl: bookCover,
                      width: 114,
                      height: 85,
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    // Indicateur vert "en direct"
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.black : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Avatar + Nom
                Row(
                  children: [
                    CachedProfileAvatar(
                      imageUrl: avatarUrl,
                      userName: displayName,
                      radius: 11,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      textColor: AppColors.primary.withValues(alpha: 0.9),
                      fontSize: 10,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Titre du livre
                Text(
                  bookTitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Depuis combien de temps
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getSinceText(),
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(isDark ? 0xFF81C784 : 0xFF388E3C),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille verte pulsante pour indiquer "en direct"
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

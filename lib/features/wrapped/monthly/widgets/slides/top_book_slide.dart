import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../monthly_wrapped_data.dart';
import '../fade_up_animation.dart';

/// Slide 3 – Top book of the month + unlocked badges.
class TopBookSlide extends StatelessWidget {
  final MonthlyWrappedData data;
  final MonthTheme theme;

  const TopBookSlide({super.key, required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'LIVRE DU MOIS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (data.topBook != null) _BookCard(book: data.topBook!, theme: theme),

        if (data.topBook == null)
          FadeUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'Aucune lecture ce mois',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),

        if (data.badges.isNotEmpty) ...[
          const SizedBox(height: 24),
          _BadgesSection(badges: data.badges),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Book card
// ---------------------------------------------------------------------------

class _BookCard extends StatelessWidget {
  final TopBookData book;
  final MonthTheme theme;

  const _BookCard({required this.book, required this.theme});

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.accent.withValues(alpha: 0.08),
              theme.accent.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: theme.accent.withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Book cover or fallback emoji
            _BookCover(url: book.coverUrl, accent: theme.accent),
            const SizedBox(height: 16),
            Text(
              book.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.author,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              book.formattedTime,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: theme.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'de lecture ce mois',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Book cover with shadow
// ---------------------------------------------------------------------------

class _BookCover extends StatelessWidget {
  final String? url;
  final Color accent;

  const _BookCover({required this.url, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Text('\uD83D\uDCD6', style: TextStyle(fontSize: 48));
    }

    return Container(
      height: 160,
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.white.withValues(alpha: 0.06),
          child: const Center(
            child: Text('\uD83D\uDCD6', style: TextStyle(fontSize: 32)),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.white.withValues(alpha: 0.06),
          child: const Center(
            child: Text('\uD83D\uDCD6', style: TextStyle(fontSize: 32)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badges section
// ---------------------------------------------------------------------------

class _BadgesSection extends StatelessWidget {
  final List<BadgeData> badges;

  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 500),
      child: Column(
        children: [
          Text(
            'BADGES DEBLOQUES',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.3),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: badges.map((b) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  b.display,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

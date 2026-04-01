import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/prize_list.dart';
import '../theme/app_theme.dart';
import 'cached_book_cover.dart';

class PrizeListsCarousel extends StatelessWidget {
  final List<PrizeList> lists;
  final Function(PrizeList list) onListTap;

  const PrizeListsCarousel({
    super.key,
    required this.lists,
    required this.onListTap,
  });

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(context, l),
        const SizedBox(height: AppSpace.m),

        // Carousel
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _PrizeListCard(
                  list: list,
                  onTap: () => onListTap(list),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6B988D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
          child: const Icon(
            LucideIcons.award,
            size: 20,
            color: Color(0xFF6B988D),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.prizeSelections,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                l.prizeSelectionsSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrizeListCard extends StatelessWidget {
  final PrizeList list;
  final VoidCallback onTap;

  const _PrizeListCard({
    required this.list,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8FB5A8),
              Color(0xFF6B988D),
              Color(0xFF4A7A6F),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Watermark icon
            Positioned(
              top: -10,
              right: -10,
              child: Icon(
                LucideIcons.award,
                size: 100,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),

            // Cover image in corner
            if (list.coverUrl != null)
              Positioned(
                top: 10,
                right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedBookCover(
                    imageUrl: list.coverUrl,
                    width: 40,
                    height: 58,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Official badge
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.award,
                                size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              AppLocalizations.of(context)!.officialLexDay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Prize name
                  Text(
                    list.prizeName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Title
                  Text(
                    list.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (list.year != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${list.year}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

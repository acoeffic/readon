import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/curated_list.dart';
import '../../../theme/app_theme.dart';

class CuratedListsCarousel extends StatefulWidget {
  final List<CuratedList> lists;
  final Map<int, int> readerCounts;
  final Set<int> savedListIds;
  final Function(int listId, bool saved) onToggleSave;
  final VoidCallback onSeeAll;
  final Function(CuratedList list) onListTap;

  const CuratedListsCarousel({
    super.key,
    required this.lists,
    required this.readerCounts,
    required this.savedListIds,
    required this.onToggleSave,
    required this.onSeeAll,
    required this.onListTap,
  });

  @override
  State<CuratedListsCarousel> createState() => _CuratedListsCarouselState();
}

class _CuratedListsCarouselState extends State<CuratedListsCarousel> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;

  /// 5 listes aléatoires + 1 carte CTA
  late final List<CuratedList> _displayedLists;
  static const int _maxDisplayed = 5;

  int get _totalItems => _displayedLists.length + 1;

  @override
  void initState() {
    super.initState();
    _displayedLists = _pickRandomLists();
    _scrollController.addListener(_onScroll);
  }

  List<CuratedList> _pickRandomLists() {
    if (widget.lists.length <= _maxDisplayed) return List.of(widget.lists);
    final shuffled = List.of(widget.lists)..shuffle(Random());
    return shuffled.take(_maxDisplayed).toList();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    const cardWidth = 200.0;
    const cardSpacing = 12.0;
    final page =
        (_scrollController.offset / (cardWidth + cardSpacing)).round();
    if (page != _currentPage && page >= 0 && page < _totalItems) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(context),
        const SizedBox(height: AppSpace.m),

        // Carousel
        SizedBox(
          height: 260,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _totalItems,
            itemBuilder: (context, index) {
              if (index < _displayedLists.length) {
                final list = _displayedLists[index];
                final isSaved = widget.savedListIds.contains(list.id);
                final readers = widget.readerCounts[list.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _CuratedListCard(
                    list: list,
                    isSaved: isSaved,
                    readerCount: readers,
                    onTap: () => widget.onListTap(list),
                    onToggleSave: () =>
                        widget.onToggleSave(list.id, !isSaved),
                  ),
                );
              } else {
                // CTA card
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _CtaCard(onTap: widget.onSeeAll),
                );
              }
            },
          ),
        ),
        const SizedBox(height: AppSpace.s),

        // Dot indicators
        _buildDotIndicators(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
          child: const Icon(
            LucideIcons.bookOpen,
            size: 20,
            color: Color(0xFFFF6B35),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listes pour toi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Sélections curatées par readon',
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
        TextButton(
          onPressed: widget.onSeeAll,
          child: const Text(
            'Voir tout →',
            style: TextStyle(
              color: Color(0xFFFF6B35),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDotIndicators() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_totalItems, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isActive
                  ? const Color(0xFFFF6B35)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }
}

class _CuratedListCard extends StatelessWidget {
  final CuratedList list;
  final bool isSaved;
  final int readerCount;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _CuratedListCard({
    required this.list,
    required this.isSaved,
    required this.readerCount,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: list.gradientColors,
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
                list.icon,
                size: 100,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: badge + heart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Book count badge
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
                            child: Text(
                              '${list.bookCount} livres',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Heart button
                      GestureDetector(
                        onTap: onToggleSave,
                        child: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Small icon
                  Icon(list.icon, size: 24, color: Colors.white),
                  const SizedBox(height: 8),

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

                  const SizedBox(height: 8),

                  // Book previews
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...list.books.take(3).toList().asMap().entries.map(
                          (entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${entry.key + 1}. ${entry.value.title}',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                        if (list.bookCount > 3)
                          Text(
                            '${list.bookCount - 3} autres…',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Reader count
                  Row(
                    children: [
                      // Mini avatar stack
                      SizedBox(
                        width: 36,
                        height: 16,
                        child: Stack(
                          children: List.generate(
                            3,
                            (i) => Positioned(
                              left: i * 10.0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withValues(alpha: 0.3 + i * 0.15),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$readerCount lecteur${readerCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
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

class _CtaCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  LucideIcons.bookOpen,
                  size: 28,
                  color: Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Voir toutes\nles listes →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

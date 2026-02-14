// pages/feed/widgets/trending_books_card.dart
// Carousel horizontal des livres les plus lus cette semaine

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_book_cover.dart';

class TrendingBooksCard extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final void Function(Map<String, dynamic> book)? onBookTap;

  const TrendingBooksCard({super.key, required this.books, this.onBookTap});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpace.s),
            Text(
              'Top livres du moment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _TrendingBookItem(
                rank: index + 1,
                title: book['book_title'] as String? ?? '',
                author: book['book_author'] as String? ?? '',
                coverUrl: book['book_cover'] as String?,
                sessionCount: (book['session_count'] as num?)?.toInt() ?? 0,
                readerCount: (book['reader_count'] as num?)?.toInt() ?? 0,
                onTap: onBookTap != null ? () => onBookTap!(book) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingBookItem extends StatelessWidget {
  final int rank;
  final String title;
  final String author;
  final String? coverUrl;
  final int sessionCount;
  final int readerCount;
  final VoidCallback? onTap;

  const _TrendingBookItem({
    required this.rank,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.sessionCount,
    required this.readerCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 140,
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
              // Rank badge + Cover
              Stack(
                children: [
                  CachedBookCover(
                    imageUrl: coverUrl,
                    width: 124,
                    height: 110,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s),
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Author
              Text(
                author,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Stats chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$sessionCount sessions · $readerCount lecteurs',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : AppColors.primary.withValues(alpha: 0.9),
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

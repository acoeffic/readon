// lib/widgets/suggestion_card.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/book_suggestion.dart';
import '../theme/app_theme.dart';
import 'cached_book_cover.dart';

class SuggestionCard extends StatelessWidget {
  final BookSuggestion suggestion;
  final VoidCallback? onTap;
  const SuggestionCard({
    super.key,
    required this.suggestion,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final book = suggestion.book;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Couverture du livre — fixed width
              CachedBookCover(
                imageUrl: book.coverUrl,
                isbn: book.isbn,
                googleId: book.googleId,
                title: book.title,
                author: book.author,
                width: 60,
                height: 90,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),

              // Informations du livre — takes remaining space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge du type de suggestion
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor().withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestion.iconEmoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              suggestion.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getTypeColor(),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),

                    // Titre
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Auteur
                    if (book.author != null)
                      Text(
                        book.author!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Résumé du livre
                    if (book.description != null && book.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        book.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpace.xs),

                    // Raison de la suggestion
                    Text(
                      suggestion.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Bouton résumé / commander — fixed width
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  color: AppColors.primary,
                  tooltip: AppLocalizations.of(context).bookSummary,
                  onPressed: () => _showBookSummarySheet(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookSummarySheet(BuildContext context) {
    final book = suggestion.book;
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: ListView(
            controller: scrollController,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpace.m),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Titre
              Text(
                book.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (book.author != null) ...[
                const SizedBox(height: 4),
                Text(
                  book.author!,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.m),
              // Résumé
              Text(
                l10n.bookSummary,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                book.description?.isNotEmpty == true
                    ? book.description!
                    : l10n.noDescriptionAvailable,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpace.l),
              // Bouton Amazon
              FilledButton.icon(
                onPressed: () => _openAmazon(book.isbn, book.title, book.author),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(l10n.buyOnAmazon),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAmazon(String? isbn, String title, String? author) async {
    final String query;
    if (isbn != null && isbn.isNotEmpty) {
      query = isbn;
    } else {
      query = [title, if (author != null) author].join(' ');
    }
    final url = Uri.parse(
      'https://www.amazon.fr/s?k=${Uri.encodeComponent(query)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Color _getTypeColor() {
    switch (suggestion.type) {
      case SuggestionType.friendsReading:
        return Colors.blue;
      case SuggestionType.sameAuthor:
        return AppColors.primary;
      case SuggestionType.similarGenre:
        return Colors.green;
      case SuggestionType.googleBooks:
        return Colors.orange;
      case SuggestionType.trending:
        return Colors.red;
      case SuggestionType.aiRecommended:
        return Colors.purple;
    }
  }
}

/// Widget pour afficher une liste horizontale de suggestions
class SuggestionsCarousel extends StatelessWidget {
  final List<BookSuggestion> suggestions;
  final Function(BookSuggestion)? onSuggestionTap;
  const SuggestionsCarousel({
    super.key,
    required this.suggestions,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < suggestions.length - 1 ? AppSpace.l : 0,
            ),
            child: SizedBox(
              width: 300,
              child: SuggestionCard(
                suggestion: suggestion,
                onTap: onSuggestionTap != null
                    ? () => onSuggestionTap!(suggestion)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

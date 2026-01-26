// lib/widgets/suggestion_card.dart

import 'package:flutter/material.dart';
import '../models/book_suggestion.dart';
import '../theme/app_theme.dart';

class SuggestionCard extends StatelessWidget {
  final BookSuggestion suggestion;
  final VoidCallback? onTap;
  final VoidCallback? onAddToLibrary;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    this.onTap,
    this.onAddToLibrary,
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
              // Couverture du livre
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderCover(context);
                        },
                      )
                    : _buildPlaceholderCover(context),
              ),
              const SizedBox(width: AppSpace.m),

              // Informations du livre
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
                        color: _getTypeColor().withOpacity(0.1),
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
                          Text(
                            suggestion.typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getTypeColor(),
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

              // Bouton ajouter
              if (onAddToLibrary != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  tooltip: 'Ajouter à ma bibliothèque',
                  onPressed: onAddToLibrary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(BuildContext context) {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.book,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        size: 30,
      ),
    );
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
    }
  }
}

/// Widget pour afficher une liste horizontale de suggestions
class SuggestionsCarousel extends StatelessWidget {
  final List<BookSuggestion> suggestions;
  final Function(BookSuggestion)? onSuggestionTap;
  final Function(BookSuggestion)? onAddToLibrary;

  const SuggestionsCarousel({
    super.key,
    required this.suggestions,
    this.onSuggestionTap,
    this.onAddToLibrary,
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
          return SizedBox(
            width: 300,
            child: SuggestionCard(
              suggestion: suggestion,
              onTap: onSuggestionTap != null
                  ? () => onSuggestionTap!(suggestion)
                  : null,
              onAddToLibrary: onAddToLibrary != null
                  ? () => onAddToLibrary!(suggestion)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

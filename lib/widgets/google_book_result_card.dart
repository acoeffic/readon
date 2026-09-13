import 'package:flutter/material.dart';

import '../services/google_books_service.dart';
import '../theme/app_theme.dart';
import 'cached_book_cover.dart';

/// Carte de résultat de recherche Google Books (couverture, titre, auteur,
/// tags). Tap → [onTap] (fiche du livre) ; bouton + → [onAdd].
/// Si [onAdd] est null, le bouton d'ajout est masqué (mode sélection).
class GoogleBookResultCard extends StatelessWidget {
  final GoogleBook googleBook;
  final bool isAdded;
  final VoidCallback? onAdd;
  final VoidCallback onTap;

  const GoogleBookResultCard({
    super.key,
    required this.googleBook,
    required this.onTap,
    this.isAdded = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.m),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                CachedBookCover(
                  imageUrl: googleBook.coverUrl,
                  isbn: googleBook.isbn13,
                  googleId: googleBook.id,
                  title: googleBook.title,
                  author: googleBook.authorsString,
                  width: 48,
                  height: 70,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        googleBook.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        googleBook.authorsString,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Métadonnées
                      Row(
                        children: [
                          if (googleBook.language != null)
                            _tag(context, googleBook.language!.toUpperCase()),
                          if (googleBook.pageCount != null &&
                              googleBook.pageCount! > 0) ...[
                            if (googleBook.language != null)
                              const SizedBox(width: 6),
                            _tag(context, '${googleBook.pageCount} p.'),
                          ],
                          if (googleBook.genre != null) ...[
                            const SizedBox(width: 6),
                            Flexible(child: _tag(context, googleBook.genre!)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Bouton ajouter (masqué en mode sélection)
                if (onAdd != null)
                  IconButton(
                    icon: Icon(
                      isAdded ? Icons.check_circle : Icons.add_circle_outline,
                      color: isAdded ? const Color(0xFFFF6B35) : null,
                      size: 26,
                    ),
                    onPressed: isAdded ? null : onAdd,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/google_books_service.dart';
import '../theme/app_theme.dart';
import '../utils/amazon_affiliate.dart';
import 'cached_book_cover.dart';

/// Fiche d'un livre Google Books en bottom sheet : couverture, métadonnées
/// et résumé, avec un bouton d'ajout en bas.
/// [onAdd] est appelé APRÈS la fermeture du sheet (pour laisser la page
/// appelante gérer sa propre navigation, p. ex. un pop vers la liste).
Future<void> showGoogleBookPreviewSheet(
  BuildContext context, {
  required GoogleBook googleBook,
  required bool isAdded,
  required VoidCallback onAdd,
  String? addButtonLabel,
}) {
  final l10n = AppLocalizations.of(context);
  final description =
      googleBook.description?.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  // Google Books renvoie « 2019 », « 2019-08 » ou « 2019-08-23T00:00:00+02:00 » :
  // on n'affiche que l'année.
  final publishedYear = _publishedYear(googleBook.publishedDate);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Poignée
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.m, AppSpace.s, AppSpace.m, AppSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CachedBookCover(
                              imageUrl: googleBook.coverUrl,
                              isbn: googleBook.isbn13,
                              googleId: googleBook.id,
                              title: googleBook.title,
                              author: googleBook.authorsString,
                              width: 90,
                              height: 132,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    googleBook.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    googleBook.authorsString,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (googleBook.language != null)
                                        _sheetTag(theme,
                                            googleBook.language!.toUpperCase()),
                                      if (googleBook.pageCount != null &&
                                          googleBook.pageCount! > 0)
                                        _sheetTag(theme,
                                            '${googleBook.pageCount} p.'),
                                      if (googleBook.genre != null)
                                        _sheetTag(theme, googleBook.genre!),
                                    ],
                                  ),
                                  if (googleBook.publisher != null ||
                                      publishedYear != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      [
                                        if (googleBook.publisher != null)
                                          googleBook.publisher!,
                                        if (publishedYear != null)
                                          publishedYear,
                                      ].join(' · '),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.l),
                        Text(
                          l10n.bookSummary,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpace.s),
                        Text(
                          (description != null && description.isNotEmpty)
                              ? description
                              : l10n.noDescriptionAvailable,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Boutons : ajout (principal) + Amazon (secondaire)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.m, AppSpace.s, AppSpace.m, AppSpace.s),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: isAdded
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    onAdd();
                                  },
                            icon: Icon(
                              isAdded
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              size: 20,
                            ),
                            label:
                                Text(addButtonLabel ?? l10n.addToThisList),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => AmazonAffiliate.openForBook(
                              isbn: googleBook.isbn13,
                              title: googleBook.title,
                              author: googleBook.authors.isNotEmpty
                                  ? googleBook.authors.first
                                  : null,
                              source: AmazonClickSource.searchPreview,
                            ),
                            icon: const Icon(Icons.shopping_cart_outlined,
                                size: 20),
                            label: Text(l10n.buyOnAmazon),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String? _publishedYear(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^\d{4}').firstMatch(raw.trim());
  return m?.group(0);
}

Widget _sheetTag(ThemeData theme, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
    ),
  );
}

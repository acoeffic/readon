import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/google_book_preview_sheet.dart';
import '../../widgets/google_book_result_card.dart';

/// Tous les livres d'un auteur (Google Books, requête inauthor).
///
/// Deux modes :
/// - [selectionMode] : tap sur un livre → pop avec le [GoogleBook] choisi
///   (utilisé depuis la recherche manuelle, qui pop elle-même ensuite).
/// - [listId] fourni : tap → fiche du livre, ajout à la liste, puis pop
///   avec `true` pour que la page appelante revienne à la liste.
class AuthorBooksPage extends StatefulWidget {
  final String author;
  final bool selectionMode;
  final int? listId;
  final Set<String> existingGoogleIds;

  const AuthorBooksPage({
    super.key,
    required this.author,
    this.selectionMode = false,
    this.listId,
    this.existingGoogleIds = const {},
  });

  @override
  State<AuthorBooksPage> createState() => _AuthorBooksPageState();
}

class _AuthorBooksPageState extends State<AuthorBooksPage> {
  final _googleBooksService = GoogleBooksService();
  final _booksService = BooksService();
  final _customListsService = UserCustomListsService();

  List<GoogleBook> _books = [];
  bool _isLoading = true;
  final Set<String> _addedGoogleIds = {};

  @override
  void initState() {
    super.initState();
    _addedGoogleIds.addAll(widget.existingGoogleIds);
    _load();
  }

  Future<void> _load() async {
    try {
      final books =
          await _googleBooksService.searchBooksByAuthor(widget.author);
      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur AuthorBooksPage._load: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToList(GoogleBook googleBook) async {
    if (widget.listId == null) return;
    if (_addedGoogleIds.contains(googleBook.id)) return;

    setState(() => _addedGoogleIds.add(googleBook.id));

    try {
      final book = await _booksService.addBookFromGoogleBooks(googleBook);
      await _customListsService.addBookToList(widget.listId!, book.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).bookAddedShort(googleBook.title)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        // Laisser le temps de voir la coche puis revenir vers la liste
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addedGoogleIds.remove(googleBook.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)
                  .errorGeneric(e.toString())),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onBookTap(GoogleBook googleBook) {
    if (widget.selectionMode) {
      Navigator.of(context).pop(googleBook);
      return;
    }
    showGoogleBookPreviewSheet(
      context,
      googleBook: googleBook,
      isAdded: _addedGoogleIds.contains(googleBook.id),
      onAdd: () => _addToList(googleBook),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.author, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (!_isLoading && _books.isNotEmpty)
              Text(
                l10n.nBooks(_books.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
      body: ConstrainedContent(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _books.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.searchX,
                              size: 40,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noResult,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _books.length,
                    itemBuilder: (context, index) {
                      final googleBook = _books[index];
                      return GoogleBookResultCard(
                        googleBook: googleBook,
                        isAdded: _addedGoogleIds.contains(googleBook.id),
                        onAdd: widget.selectionMode
                            ? null
                            : () => _addToList(googleBook),
                        onTap: () => _onBookTap(googleBook),
                      );
                    },
                  ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/author_result_card.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/google_book_preview_sheet.dart';
import '../../widgets/google_book_result_card.dart';
import '../books/author_books_page.dart';
import '../books/user_books_page.dart';

class AddBookToListPage extends StatefulWidget {
  final int listId;
  final Set<int> existingBookIds;

  const AddBookToListPage({
    super.key,
    required this.listId,
    this.existingBookIds = const {},
  });

  @override
  State<AddBookToListPage> createState() => _AddBookToListPageState();
}

class _AddBookToListPageState extends State<AddBookToListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _customListsService = UserCustomListsService();
  final _booksService = BooksService();
  final _googleBooksService = GoogleBooksService();

  // Library tab
  List<Map<String, dynamic>> _libraryBooks = [];
  bool _isLoadingLibrary = true;
  final Set<int> _addedBookIds = {};

  // Search tab
  final _searchController = TextEditingController();
  List<GoogleBook> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _addedGoogleIds = {};
  Timer? _debounce;
  int _searchSeq = 0;
  String? _detectedAuthor;

  // Library filter
  String _libraryFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addedBookIds.addAll(widget.existingBookIds);
    _loadLibrary();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    try {
      final books = await _booksService.getUserBooksWithStatusPaginated(
        limit: 200,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _libraryBooks = books;
          _isLoadingLibrary = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadLibrary: $e');
      if (mounted) setState(() => _isLoadingLibrary = false);
    }
  }

  Future<void> _toggleLibraryBook(Book book) async {
    final isAdded = _addedBookIds.contains(book.id);

    setState(() {
      if (isAdded) {
        _addedBookIds.remove(book.id);
      } else {
        _addedBookIds.add(book.id);
      }
    });

    try {
      if (isAdded) {
        await _customListsService.removeBookFromList(widget.listId, book.id);
      } else {
        await _customListsService.addBookToList(widget.listId, book.id);
      }
    } catch (e) {
      // Rollback
      if (mounted) {
        setState(() {
          if (isAdded) {
            _addedBookIds.add(book.id);
          } else {
            _addedBookIds.remove(book.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorGeneric(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _detectedAuthor = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchBooks(value);
    });
  }

  Future<void> _searchBooks(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    final seq = ++_searchSeq;
    setState(() => _isSearching = true);

    try {
      // Recherche optimisée : 2 requêtes en parallèle (voie rapide),
      // fusion + tri par pertinence, cache mémoire — voir GoogleBooksService.
      final merged = await _googleBooksService.searchBooksRanked(trimmed);

      // Ignorer les réponses obsolètes (l'utilisateur a continué à taper)
      if (mounted && seq == _searchSeq) {
        setState(() {
          _searchResults = merged;
          // La requête ressemble-t-elle à un nom d'auteur ?
          _detectedAuthor =
              GoogleBooksService.detectAuthorQuery(trimmed, merged);
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur _searchBooks: $e');
      if (mounted && seq == _searchSeq) setState(() => _isSearching = false);
    }
  }

  Future<void> _addGoogleBook(GoogleBook googleBook) async {
    if (_addedGoogleIds.contains(googleBook.id)) return;

    setState(() => _addedGoogleIds.add(googleBook.id));

    try {
      // D'abord ajouter le livre à la bibliothèque
      final book = await _booksService.addBookFromGoogleBooks(googleBook);
      // Puis l'ajouter à la liste
      await _customListsService.addBookToList(widget.listId, book.id);
      _addedBookIds.add(book.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).bookAddedShort(googleBook.title)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        // Laisser le temps de voir la coche puis revenir sur la liste
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addedGoogleIds.remove(googleBook.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorGeneric(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Ouvre la page « tous les livres de cet auteur ».
  /// Si un livre y est ajouté, on revient directement sur la liste.
  Future<void> _openAuthorBooks(String author) async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthorBooksPage(
          author: author,
          listId: widget.listId,
          existingGoogleIds: _addedGoogleIds,
        ),
      ),
    );
    if (added == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).addBooksTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              Theme.of(context).textTheme.bodyMedium?.color,
          tabs: [
            Tab(text: AppLocalizations.of(context).myLibrary),
            Tab(text: AppLocalizations.of(context).searchLabel),
          ],
        ),
      ),
      body: ConstrainedContent(
        child: TabBarView(
        controller: _tabController,
        children: [
          _buildLibraryTab(),
          _buildSearchTab(),
        ],
      ),
      ),
    );
  }

  Widget _buildLibraryTab() {
    if (_isLoadingLibrary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_libraryBooks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.bookOpen,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).emptyLibrary,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).emptyLibraryUseSearch,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filterLower = _libraryFilter.toLowerCase();
    final filtered = filterLower.isEmpty
        ? _libraryBooks
        : _libraryBooks.where((item) {
            final book = item['book'] as Book;
            return book.title.toLowerCase().contains(filterLower) ||
                (book.author?.toLowerCase().contains(filterLower) ?? false);
          }).toList();

    return Column(
      children: [
        // Barre de filtre local
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.m, AppSpace.m, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).filterLibrary,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
            onChanged: (v) => setState(() => _libraryFilter = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              final book = item['book'] as Book;
              final isAdded = _addedBookIds.contains(book.id);

              return ListTile(
                leading: CachedBookCover(
                  imageUrl: book.coverUrl,
                  isbn: book.isbn,
                  googleId: book.googleId,
                  title: book.title,
                  author: book.author,
                  width: 40,
                  height: 58,
                  borderRadius: BorderRadius.circular(4),
                ),
                title: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: book.author != null
                    ? Text(
                        book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      )
                    : null,
                trailing: IconButton(
                  icon: Icon(
                    isAdded ? Icons.check_circle : Icons.add_circle_outline,
                    color: isAdded ? const Color(0xFFFF6B35) : null,
                  ),
                  onPressed: () => _toggleLibraryBook(book),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailPage(book: book),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchTitleAuthor,
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _detectedAuthor = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
            onSubmitted: _searchBooks,
            onChanged: _onSearchChanged,
          ),
        ),
        // Barre fine pendant la recherche : les résultats précédents
        // restent visibles au lieu d'être remplacés par un spinner.
        if (_isSearching) const LinearProgressIndicator(minHeight: 2),
        if (_searchResults.isEmpty && _isSearching)
          const Expanded(child: SizedBox.shrink())
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.searchX,
                        size: 40,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).noResult,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).tryMoreSpecific,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.search,
                        size: 40,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).searchBookByTitleAuthorHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length +
                  (_detectedAuthor != null ? 1 : 0),
              itemBuilder: (context, index) {
                // Carte auteur en tête quand la requête est un nom d'auteur
                if (_detectedAuthor != null && index == 0) {
                  return AuthorResultCard(
                    authorName: _detectedAuthor!,
                    onTap: () => _openAuthorBooks(_detectedAuthor!),
                  );
                }
                final googleBook = _searchResults[
                    _detectedAuthor != null ? index - 1 : index];
                final isAdded = _addedGoogleIds.contains(googleBook.id);

                return GoogleBookResultCard(
                  googleBook: googleBook,
                  isAdded: isAdded,
                  onAdd: () => _addGoogleBook(googleBook),
                  onTap: () => showGoogleBookPreviewSheet(
                    context,
                    googleBook: googleBook,
                    isAdded: isAdded,
                    onAdd: () => _addGoogleBook(googleBook),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

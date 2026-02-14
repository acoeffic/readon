import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/book.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

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
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchBooks(value);
    });
  }

  Future<void> _searchBooks(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Lancer 2 recherches en parallèle pour de meilleurs résultats
      final results = await Future.wait([
        // 1) Recherche FR restreinte
        _googleBooksService.searchBooks(trimmed, langRestrict: true),
        // 2) Recherche avec intitle: (toutes langues)
        _googleBooksService.searchBooks('intitle:$trimmed'),
      ]);

      final frResults = results[0];
      final titleResults = results[1];

      // Fusionner et dédupliquer
      final merged = _mergeAndRank(frResults, titleResults);

      if (mounted) {
        setState(() {
          _searchResults = merged;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur _searchBooks: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Fusionne deux listes de résultats, déduplique et trie par pertinence
  List<GoogleBook> _mergeAndRank(
      List<GoogleBook> primary, List<GoogleBook> secondary) {
    final seen = <String>{};
    final all = <GoogleBook>[];

    void addIfNew(GoogleBook book) {
      // Déduplier par ID Google
      if (seen.contains(book.id)) return;

      // Déduplier par ISBN
      for (final isbn in book.isbns) {
        if (seen.contains(isbn)) return;
      }

      // Déduplier par titre+auteur normalisé
      final key =
          '${book.title.toLowerCase().trim()}|${book.authorsString.toLowerCase().trim()}';
      if (seen.contains(key)) return;

      seen.add(book.id);
      for (final isbn in book.isbns) {
        seen.add(isbn);
      }
      seen.add(key);
      all.add(book);
    }

    // Les résultats FR d'abord
    for (final book in primary) {
      addIfNew(book);
    }
    for (final book in secondary) {
      addIfNew(book);
    }

    // Trier par score de pertinence
    all.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));

    return all;
  }

  /// Score de pertinence : plus c'est haut, plus c'est pertinent
  int _relevanceScore(GoogleBook book) {
    int score = 0;
    if (book.language == 'fr') {
      score += 5;
    }
    if (book.coverUrl != null && !book.coverUrl!.contains('openlibrary')) {
      score += 3;
    }
    if (book.authors.isNotEmpty && book.authors.first != 'Auteur inconnu') {
      score += 2;
    }
    if (book.pageCount != null && book.pageCount! > 0) {
      score += 1;
    }
    if (book.description != null && book.description!.isNotEmpty) {
      score += 1;
    }
    if (book.isbns.isNotEmpty) {
      score += 1;
    }
    return score;
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
            content: Text('${googleBook.title} ajouté'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addedGoogleIds.remove(googleBook.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter des livres'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              Theme.of(context).textTheme.bodyMedium?.color,
          tabs: const [
            Tab(text: 'Ma bibliothèque'),
            Tab(text: 'Rechercher'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLibraryTab(),
          _buildSearchTab(),
        ],
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
                'Bibliothèque vide',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Utilise l\'onglet Rechercher pour trouver et ajouter des livres.',
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
              hintText: 'Filtrer ma bibliothèque...',
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
              hintText: 'Rechercher un titre ou un auteur...',
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchController.clear();
                        setState(() => _searchResults = []);
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
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
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
                      'Aucun résultat',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Essaie avec un titre plus précis',
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
                      'Recherche un livre par titre ou auteur',
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
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final googleBook = _searchResults[index];
                final isAdded = _addedGoogleIds.contains(googleBook.id);

                return _SearchResultCard(
                  googleBook: googleBook,
                  isAdded: isAdded,
                  onAdd: () => _addGoogleBook(googleBook),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final GoogleBook googleBook;
  final bool isAdded;
  final VoidCallback onAdd;

  const _SearchResultCard({
    required this.googleBook,
    required this.isAdded,
    required this.onAdd,
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
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: googleBook.coverUrl != null
                    ? Image.network(
                        googleBook.coverUrl!,
                        width: 48,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
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
                        if (googleBook.pageCount != null) ...[
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

              // Bouton ajouter
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
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.book, size: 20, color: Colors.grey),
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

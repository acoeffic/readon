import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/curated_list.dart';
import '../../services/curated_lists_service.dart';
import '../../services/google_books_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bookstores/nearby_bookstores_page.dart';
import '../../models/user_custom_list.dart';
import '../../services/books_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import 'create_custom_list_dialog.dart';

class CuratedListDetailPage extends StatefulWidget {
  final CuratedList list;

  const CuratedListDetailPage({super.key, required this.list});

  @override
  State<CuratedListDetailPage> createState() => _CuratedListDetailPageState();
}

class _CuratedListDetailPageState extends State<CuratedListDetailPage> {
  final _curatedService = CuratedListsService();
  final _googleBooksService = GoogleBooksService();
  final _booksService = BooksService();
  final _customListsService = UserCustomListsService();

  bool _isLoading = true;
  bool _isSaved = false;
  Set<String> _readIsbns = {};
  int _readerCount = 0;

  // Google Books data par ISBN
  final Map<String, GoogleBook> _googleBooks = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _curatedService.isListSaved(widget.list.id),
        _curatedService.getReadBookIsbns(widget.list.id),
        _curatedService.getReaderCounts([widget.list.id]),
      ]);

      if (!mounted) return;
      setState(() {
        _isSaved = results[0] as bool;
        _readIsbns = results[1] as Set<String>;
        final counts = results[2] as Map<int, int>;
        _readerCount = counts[widget.list.id] ?? 0;
        _isLoading = false;
      });

      // Charger les données Google Books en arrière-plan
      _loadGoogleBooksData();
    } catch (e) {
      debugPrint('Erreur _loadData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGoogleBooksData() async {
    // Phase 1 : Afficher immédiatement les couvertures depuis le cache persistant
    for (final book in widget.list.books) {
      if (!mounted) return;
      final cachedUrl = _googleBooksService.getCachedCoverUrl(book.isbn);
      if (cachedUrl != null) {
        setState(() {
          _googleBooks[book.isbn] = GoogleBook(
            id: 'cached-${book.isbn}',
            title: book.title,
            authors: [book.author],
            coverUrl: cachedUrl,
            isbns: [book.isbn],
          );
        });
      }
    }

    // Phase 2 : Charger les données complètes en arrière-plan pour les ISBN non cachés
    for (final book in widget.list.books) {
      if (!mounted) return;
      // Skip si déjà chargé depuis le cache mémoire complet (pas juste le persistant)
      if (_googleBooks.containsKey(book.isbn) &&
          !_googleBooks[book.isbn]!.id.startsWith('cached-')) {
        continue;
      }
      try {
        GoogleBook? result;

        // 1) Recherche par ISBN (utilise le cache interne du service)
        result = await _googleBooksService.searchByISBN(book.isbn);

        // 2) Fallback : titre + auteur (opérateurs intitle/inauthor)
        if (result == null) {
          final results = await _googleBooksService.searchByTitleAuthor(
            book.title,
            book.author,
          );
          if (results.isNotEmpty) result = results.first;
        }

        // 3) Fallback : recherche libre simplifiée (sans opérateurs)
        if (result == null) {
          final simplifiedTitle =
              book.title.replaceAll("'", ' ').replaceAll("'", ' ');
          final results = await _googleBooksService
              .searchBooks('$simplifiedTitle ${book.author}');
          if (results.isNotEmpty) result = results.first;
        }

        // 4) Dernier recours : objet minimal avec couverture Open Library
        result ??= GoogleBook(
          id: 'ol-${book.isbn}',
          title: book.title,
          authors: [book.author],
          coverUrl: 'https://covers.openlibrary.org/b/isbn/${book.isbn}-L.jpg',
          isbns: [book.isbn],
        );

        // Mettre en cache le résultat (y compris les fallbacks)
        _googleBooksService.cacheBook(book.isbn, result);

        if (mounted) {
          setState(() => _googleBooks[book.isbn] = result!);
        }
      } catch (e) {
        debugPrint('Erreur chargement Google Book ${book.isbn}: $e');
        // Même en cas d'erreur, on met la couverture Open Library
        if (mounted && !_googleBooks.containsKey(book.isbn)) {
          final fallback = GoogleBook(
            id: 'ol-${book.isbn}',
            title: book.title,
            authors: [book.author],
            coverUrl:
                'https://covers.openlibrary.org/b/isbn/${book.isbn}-L.jpg',
            isbns: [book.isbn],
          );
          _googleBooksService.cacheBook(book.isbn, fallback);
          setState(() => _googleBooks[book.isbn] = fallback);
        }
      }
    }
  }

  void _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);

    try {
      if (!wasSaved) {
        await _curatedService.saveList(widget.list.id);
      } else {
        await _curatedService.unsaveList(widget.list.id);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaved = wasSaved);
    }
  }

  void _toggleBookRead(CuratedBookEntry book) async {
    final wasRead = _readIsbns.contains(book.isbn);
    setState(() {
      if (wasRead) {
        _readIsbns.remove(book.isbn);
      } else {
        _readIsbns.add(book.isbn);
      }
    });

    try {
      if (!wasRead) {
        await _curatedService.markBookRead(widget.list.id, book.isbn);
      } else {
        await _curatedService.unmarkBookRead(widget.list.id, book.isbn);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasRead) {
            _readIsbns.add(book.isbn);
          } else {
            _readIsbns.remove(book.isbn);
          }
        });
      }
    }
  }

  void _onBookTap(CuratedBookEntry book) {
    final googleBook = _googleBooks[book.isbn];
    if (googleBook != null) {
      _showBookDetailSheet(book, googleBook);
    } else {
      // Données pas encore chargées, on les charge à la volée
      _loadAndShowBook(book);
    }
  }

  Future<void> _loadAndShowBook(CuratedBookEntry book) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      GoogleBook? googleBook;

      // 1) ISBN
      googleBook = await _googleBooksService.searchByISBN(book.isbn);

      // 2) titre + auteur
      if (googleBook == null) {
        final results = await _googleBooksService.searchByTitleAuthor(
          book.title,
          book.author,
        );
        if (results.isNotEmpty) googleBook = results.first;
      }

      // 3) recherche libre simplifiée
      if (googleBook == null) {
        final simplifiedTitle =
            book.title.replaceAll("'", ' ').replaceAll("'", ' ');
        final results = await _googleBooksService
            .searchBooks('$simplifiedTitle ${book.author}');
        if (results.isNotEmpty) googleBook = results.first;
      }

      // 4) objet minimal Open Library
      googleBook ??= GoogleBook(
        id: 'ol-${book.isbn}',
        title: book.title,
        authors: [book.author],
        coverUrl: 'https://covers.openlibrary.org/b/isbn/${book.isbn}-L.jpg',
        isbns: [book.isbn],
      );

      if (!mounted) return;
      Navigator.pop(context);

      setState(() => _googleBooks[book.isbn] = googleBook!);
      _showBookDetailSheet(book, googleBook);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        // Même en erreur, on ouvre avec couverture Open Library
        final fallback = GoogleBook(
          id: 'ol-${book.isbn}',
          title: book.title,
          authors: [book.author],
          coverUrl:
              'https://covers.openlibrary.org/b/isbn/${book.isbn}-L.jpg',
          isbns: [book.isbn],
        );
        setState(() => _googleBooks[book.isbn] = fallback);
        _showBookDetailSheet(book, fallback);
      }
    }
  }

  void _showBookDetailSheet(CuratedBookEntry entry, GoogleBook googleBook) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  CachedBookCover(
                    imageUrl: googleBook.coverUrl,
                    isbn: googleBook.isbn13,
                    googleId: googleBook.id,
                    width: 100,
                    height: 150,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.author,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        if (googleBook.pageCount != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${googleBook.pageCount} pages',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        if (googleBook.genre != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              googleBook.genre!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFF6B35),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showAddToListSheet(entry, googleBook);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFF6B35)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.listPlus,
                                  size: 14,
                                  color: Color(0xFFFF6B35),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l.addToList,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (googleBook.description != null) ...[
                const SizedBox(height: 20),
                Text(
                  l.description,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  googleBook.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildBuyOption(
                      context: context,
                      emoji: '📖',
                      label: l.inBookstore,
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${entry.title} ${entry.author}'.trim(),
                        );
                        launchUrl(
                          Uri.parse('https://www.leslibraires.fr/recherche?q=$query'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                    _buildBuyOption(
                      context: context,
                      emoji: '🏪',
                      label: l.findNearMe,
                      onTap: () => _openNearbyBookstores(context),
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                    _buildBuyOption(
                      context: context,
                      emoji: '📦',
                      label: l.amazon,
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${entry.title} ${entry.author}'.trim(),
                        );
                        launchUrl(
                          Uri.parse('https://www.amazon.fr/s?k=$query&i=stripbooks&tag=lexday-21'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToListSheet(CuratedBookEntry entry, GoogleBook googleBook) async {
    // Trouver ou créer le livre dans la base sans l'ajouter à la bibliothèque
    try {
      final book = await _booksService.findOrCreateBook(googleBook);

      final results = await Future.wait([
        _customListsService.getUserLists(),
        _customListsService.getListIdsContainingBook(book.id),
      ]);

      final lists = results[0] as List<UserCustomList>;
      final containingIds = results[1] as Set<int>;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _CuratedAddToListSheet(
          lists: lists,
          containingIds: containingIds,
          bookId: book.id,
          service: _customListsService,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openNearbyBookstores(BuildContext parentContext) {
    Navigator.push(
      parentContext,
      MaterialPageRoute(builder: (_) => const NearbyBookstoresPage()),
    );
  }

  Widget _buildBuyOption({
    required BuildContext context,
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final readCount = _readIsbns.length;
    final totalBooks = widget.list.bookCount;
    final progress = totalBooks > 0 ? readCount / totalBooks : 0.0;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Gradient header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
                onPressed: _toggleSave,
              ),
              IconButton(
                icon:
                    const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {
                  // TODO: share functionality
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.list.gradientColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      right: -20,
                      child: Icon(
                        widget.list.icon,
                        size: 160,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.list.icon,
                              size: 28, color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            widget.list.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.list.subtitle,
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Stats + description (fixed)
            Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.bookOpen,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        l.nBooks(totalBooks),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.people_outline,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        l.nReaders(_readerCount),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.list.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.1),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B35),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l.nRead(readCount, totalBooks),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Book list (scrollable)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: widget.list.books.length,
                      itemBuilder: (context, index) {
                        final book = widget.list.books[index];
                        final isRead = _readIsbns.contains(book.isbn);
                        final googleBook = _googleBooks[book.isbn];
                        return _BookListItem(
                          book: book,
                          index: index,
                          isRead: isRead,
                          coverUrl: googleBook?.coverUrl,
                          gradientColor: widget.list.gradientColors.last,
                          onToggleRead: () => _toggleBookRead(book),
                          onTap: () => _onBookTap(book),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  final CuratedBookEntry book;
  final int index;
  final bool isRead;
  final String? coverUrl;
  final Color gradientColor;
  final VoidCallback onToggleRead;
  final VoidCallback onTap;

  const _BookListItem({
    required this.book,
    required this.index,
    required this.isRead,
    required this.coverUrl,
    required this.gradientColor,
    required this.onToggleRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isRead ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.l,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggleRead,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRead
                        ? const Color(0xFFFF6B35)
                        : Colors.transparent,
                    border: Border.all(
                      color: isRead
                          ? const Color(0xFFFF6B35)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isRead
                      ? const Icon(Icons.check,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Book cover
              _BookCover(
                coverUrl: coverUrl,
                gradientColor: gradientColor,
              ),
              const SizedBox(width: 12),

              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration:
                            isRead ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  final String? coverUrl;
  final Color gradientColor;

  const _BookCover({
    required this.coverUrl,
    required this.gradientColor,
  });

  @override
  Widget build(BuildContext context) {
    if (coverUrl != null) {
      return CachedBookCover(
        imageUrl: coverUrl,
        width: 44,
        height: 64,
        borderRadius: BorderRadius.circular(4),
      );
    }

    return Container(
      width: 44,
      height: 64,
      decoration: BoxDecoration(
        color: gradientColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.book,
        size: 20,
        color: gradientColor.withValues(alpha: 0.4),
      ),
    );
  }
}

class _CuratedAddToListSheet extends StatefulWidget {
  final List<UserCustomList> lists;
  final Set<int> containingIds;
  final int bookId;
  final UserCustomListsService service;

  const _CuratedAddToListSheet({
    required this.lists,
    required this.containingIds,
    required this.bookId,
    required this.service,
  });

  @override
  State<_CuratedAddToListSheet> createState() => _CuratedAddToListSheetState();
}

class _CuratedAddToListSheetState extends State<_CuratedAddToListSheet> {
  late Set<int> _containingIds;

  @override
  void initState() {
    super.initState();
    _containingIds = Set<int>.from(widget.containingIds);
  }

  Future<void> _toggleList(UserCustomList list) async {
    final wasInList = _containingIds.contains(list.id);
    setState(() {
      if (wasInList) {
        _containingIds.remove(list.id);
      } else {
        _containingIds.add(list.id);
      }
    });

    try {
      if (wasInList) {
        await widget.service.removeBookFromList(list.id, widget.bookId);
      } else {
        await widget.service.addBookToList(list.id, widget.bookId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasInList) {
            _containingIds.add(list.id);
          } else {
            _containingIds.remove(list.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createNewList() async {
    final l = AppLocalizations.of(context)!;
    Navigator.pop(context);
    final result = await showCreateCustomListSheet(context);
    if (result != null) {
      try {
        await widget.service.addBookToList(result.id, widget.bookId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.addedToList(result.title)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur ajout à nouvelle liste: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.addToList,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.lists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l.noPersonalList,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ...widget.lists.map((list) {
              final isInList = _containingIds.contains(list.id);
              final gradientColors = list.gradientColors;
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(list.icon, size: 18, color: Colors.white),
                ),
                title: Text(list.title),
                trailing: Icon(
                  isInList ? Icons.check_circle : Icons.circle_outlined,
                  color: isInList ? const Color(0xFFFF6B35) : null,
                ),
                onTap: () => _toggleList(list),
              );
            }),
          const Divider(),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.plus,
                  size: 18, color: Color(0xFFFF6B35)),
            ),
            title: Text(
              l.createNewList,
              style: const TextStyle(color: Color(0xFFFF6B35)),
            ),
            onTap: _createNewList,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

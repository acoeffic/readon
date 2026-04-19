import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/prize_list.dart';
import '../../services/prize_list_service.dart';
import '../../services/google_books_service.dart';
import '../../services/books_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../models/user_custom_list.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bookstores/nearby_bookstores_page.dart';
import 'create_custom_list_dialog.dart';

class PrizeListDetailPage extends StatefulWidget {
  final PrizeList prizeList;

  const PrizeListDetailPage({super.key, required this.prizeList});

  @override
  State<PrizeListDetailPage> createState() => _PrizeListDetailPageState();
}

class _PrizeListDetailPageState extends State<PrizeListDetailPage> {
  final _prizeService = PrizeListService();
  final _googleBooksService = GoogleBooksService();
  final _booksService = BooksService();
  final _customListsService = UserCustomListsService();

  bool _isLoading = true;
  List<PrizeListBook> _books = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await _prizeService.fetchBooksForList(widget.prizeList.id);
    if (!mounted) return;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  void _onBookTap(PrizeListBook book) {
    _showBookDetailSheet(book);
  }

  void _showBookDetailSheet(PrizeListBook book) {
    final l = AppLocalizations.of(context)!;
    final pageContext = context;
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
        builder: (_, scrollController) => SingleChildScrollView(
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
                    imageUrl: book.coverUrl,
                    title: book.title,
                    author: book.author,
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
                          book.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (book.author != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            book.author!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                        if (book.pageCount != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${book.pageCount} pages',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        if (book.publicationYear != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B988D)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${book.publicationYear}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B988D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showAddToListSheet(book);
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
              if (book.description != null) ...[
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
                  book.description!,
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
                      context: pageContext,
                      emoji: '\u{1F4D6}',
                      label: l.inBookstore,
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${book.title} ${book.author ?? ""}'.trim(),
                        );
                        launchUrl(
                          Uri.parse(
                              'https://www.leslibraires.fr/recherche?q=$query'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08)),
                    _buildBuyOption(
                      context: pageContext,
                      emoji: '\u{1F3EA}',
                      label: l.findNearMe,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          pageContext,
                          MaterialPageRoute(
                              builder: (_) => const NearbyBookstoresPage()),
                        );
                      },
                    ),
                    Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08)),
                    _buildBuyOption(
                      context: pageContext,
                      emoji: '\u{1F4E6}',
                      label: l.amazon,
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${book.title} ${book.author ?? ""}'.trim(),
                        );
                        launchUrl(
                          Uri.parse(
                              'https://www.amazon.fr/s?k=$query&i=stripbooks&tag=lexday-21'),
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

  void _showAddToListSheet(PrizeListBook book) async {
    try {
      // Build a GoogleBook from the prize book data to use findOrCreateBook
      final googleBook = GoogleBook(
        id: 'prize-${book.wikidataBookId ?? book.id}',
        title: book.title,
        authors: book.author != null ? [book.author!] : [],
        coverUrl: book.coverUrl,
        isbns: book.isbn != null ? [book.isbn!] : [],
        pageCount: book.pageCount,
        description: book.description,
      );

      final createdBook = await _booksService.findOrCreateBook(googleBook);

      final results = await Future.wait([
        _customListsService.getUserLists(),
        _customListsService.getListIdsContainingBook(createdBook.id),
      ]);

      final lists = results[0] as List<UserCustomList>;
      final containingIds = results[1] as Set<int>;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _PrizeAddToListSheet(
          lists: lists,
          containingIds: containingIds,
          bookId: createdBook.id,
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
        color:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final list = widget.prizeList;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient header (sage green for prize lists)
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8FB5A8),
                      Color(0xFF6B988D),
                      Color(0xFF4A7A6F),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      right: -20,
                      child: Icon(
                        LucideIcons.award,
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
                          // Official badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.award,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  l.officialLexDay,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            list.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            list.prizeName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
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

          // Description + book count
          SliverToBoxAdapter(
            child: ConstrainedContent(
              child: Padding(
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
                          l.nBooks(_books.length),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        if (list.year != null) ...[
                          const SizedBox(width: 16),
                          Icon(LucideIcons.calendar,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${list.year}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (list.description != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        list.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: Divider(height: 1)),

          // Book list
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = _books[index];
                  return _PrizeBookListItem(
                    book: book,
                    index: index,
                    onTap: () => _onBookTap(book),
                  );
                },
                childCount: _books.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _PrizeBookListItem extends StatelessWidget {
  final PrizeListBook book;
  final int index;
  final VoidCallback onTap;

  const _PrizeBookListItem({
    required this.book,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Position number
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Book cover
            _PrizeBookCover(coverUrl: book.coverUrl, title: book.title, author: book.author, isbn: book.isbn),
            const SizedBox(width: 12),

            // Book info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.author != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.author!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  if (book.publicationYear != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${book.publicationYear}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
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
    );
  }
}

class _PrizeBookCover extends StatelessWidget {
  final String? coverUrl;
  final String? title;
  final String? author;
  final String? isbn;

  const _PrizeBookCover({required this.coverUrl, this.title, this.author, this.isbn});

  @override
  Widget build(BuildContext context) {
    return CachedBookCover(
      imageUrl: coverUrl,
      isbn: isbn,
      title: title,
      author: author,
      width: 44,
      height: 64,
      borderRadius: BorderRadius.circular(4),
    );
  }
}

class _PrizeAddToListSheet extends StatefulWidget {
  final List<UserCustomList> lists;
  final Set<int> containingIds;
  final int bookId;
  final UserCustomListsService service;

  const _PrizeAddToListSheet({
    required this.lists,
    required this.containingIds,
    required this.bookId,
    required this.service,
  });

  @override
  State<_PrizeAddToListSheet> createState() => _PrizeAddToListSheetState();
}

class _PrizeAddToListSheetState extends State<_PrizeAddToListSheet> {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

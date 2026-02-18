import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/book.dart';
import '../../models/user_custom_list.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import 'add_book_to_list_page.dart';
import 'create_custom_list_dialog.dart';

class CustomListDetailPage extends StatefulWidget {
  final UserCustomList list;

  const CustomListDetailPage({super.key, required this.list});

  @override
  State<CustomListDetailPage> createState() => _CustomListDetailPageState();
}

class _CustomListDetailPageState extends State<CustomListDetailPage> {
  final _service = UserCustomListsService();

  bool _isLoading = true;
  late UserCustomList _list;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final listWithBooks = await _service.getListWithBooks(widget.list.id);
      if (!mounted) return;
      setState(() {
        _list = listWithBooks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur _loadData CustomListDetail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editList() async {
    final result = await showCreateCustomListSheet(
      context,
      existingList: _list,
    );

    if (result != null && mounted) {
      setState(() {
        _list = result.copyWith(books: _list.books);
      });
    }
  }

  Future<void> _deleteList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette liste ?'),
        content: Text(
            'La liste "${_list.title}" sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteList(_list.id);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBookDetailSheet(Book book) {
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
                  CachedBookCover(
                    imageUrl: book.coverUrl,
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
                        if (book.author != null &&
                            book.author!.isNotEmpty) ...[
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
                        if (book.genre != null) ...[
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
                              book.genre!,
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.listPlus,
                                  size: 14,
                                  color: Color(0xFFFF6B35),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Ajouter à une liste',
                                  style: TextStyle(
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
                  'Description',
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToListSheet(Book book) async {
    final results = await Future.wait([
      _service.getUserLists(),
      _service.getListIdsContainingBook(book.id),
    ]);

    final lists = results[0] as List<UserCustomList>;
    final containingIds = results[1] as Set<int>;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddToListSheet(
        lists: lists,
        containingIds: containingIds,
        bookId: book.id,
        service: _service,
      ),
    );
  }

  Future<void> _addBooks() async {
    final existingBookIds = _list.books.map((b) => b.id).toSet();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBookToListPage(
          listId: _list.id,
          existingBookIds: existingBookIds,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _removeBook(Book book) async {
    final books = List<Book>.from(_list.books);
    books.removeWhere((b) => b.id == book.id);
    setState(() => _list = _list.copyWith(books: books));

    try {
      await _service.removeBookFromList(_list.id, book.id);
    } catch (e) {
      // Rollback
      if (mounted) {
        setState(() => _list = _list.copyWith(books: [...books, book]));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _list.gradientColors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header gradient
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.pencil, color: Colors.white),
                tooltip: 'Modifier',
                onPressed: _editList,
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.white),
                tooltip: 'Supprimer',
                onPressed: _deleteList,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      right: -20,
                      child: Icon(
                        _list.icon,
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
                          Icon(_list.icon, size: 28, color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            _list.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
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

          // Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Row(
                children: [
                  Icon(LucideIcons.bookOpen,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '${_list.bookCount} livre${_list.bookCount > 1 ? 's' : ''}',
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
            ),
          ),

          const SliverToBoxAdapter(child: Divider(height: 1)),

          // Book list or empty state
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_list.books.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = _list.books[index];
                  return _CustomBookListItem(
                    book: book,
                    gradientColor: gradientColors.last,
                    onRemove: () => _removeBook(book),
                    onTap: () => _showBookDetailSheet(book),
                  );
                },
                childCount: _list.books.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBooks,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Ajouter un livre'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
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
            'Aucun livre dans cette liste',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoute des livres depuis ta bibliothèque ou en recherchant un titre.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _addBooks,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Ajouter un livre'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomBookListItem extends StatelessWidget {
  final Book book;
  final Color gradientColor;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _CustomBookListItem({
    required this.book,
    required this.gradientColor,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('custom_book_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withValues(alpha: 0.1),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Retirer ce livre ?'),
                content: Text(
                    'Retirer "${book.title}" de cette liste ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Retirer'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onRemove(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Cover
            CachedBookCover(
              imageUrl: book.coverUrl,
              width: 44,
              height: 64,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(width: 12),

            // Info
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
                  if (book.author != null && book.author!.isNotEmpty) ...[
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

class _AddToListSheet extends StatefulWidget {
  final List<UserCustomList> lists;
  final Set<int> containingIds;
  final int bookId;
  final UserCustomListsService service;

  const _AddToListSheet({
    required this.lists,
    required this.containingIds,
    required this.bookId,
    required this.service,
  });

  @override
  State<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<_AddToListSheet> {
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
    Navigator.pop(context);
    final result = await showCreateCustomListSheet(context);
    if (result != null) {
      try {
        await widget.service.addBookToList(result.id, widget.bookId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ajouté à "${result.title}"'),
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
              'Ajouter à une liste',
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
                'Aucune liste personnelle.',
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
            title: const Text(
              'Créer une nouvelle liste',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
            onTap: _createNewList,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

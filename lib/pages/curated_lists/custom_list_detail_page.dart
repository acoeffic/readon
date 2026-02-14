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

  const _CustomBookListItem({
    required this.book,
    required this.gradientColor,
    required this.onRemove,
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
    );
  }
}

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/book.dart';
import '../../models/user_custom_list.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import 'add_book_to_list_page.dart';
import 'create_custom_list_dialog.dart';
import 'list_share_service.dart';
import '../../widgets/constrained_content.dart';
import '../books/user_books_page.dart';

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
  String? _ownerName;

  bool get _isOwner =>
      _list.userId == Supabase.instance.client.auth.currentUser?.id;

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
      if (!_isOwner && _ownerName == null) {
        final name = await _service.getListOwnerName(_list.userId);
        if (mounted) setState(() => _ownerName = name);
      }
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
    final l = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteListTitle),
        content: Text(l.deleteListMessage(_list.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.deleteButton),
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

  Future<void> _shareList() async {
    final l = AppLocalizations.of(context)!;

    // Rendre la liste publique si besoin (avec confirmation).
    if (!_list.isPublic) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.listShareMakePublicTitle),
          content: Text(l.listShareMakePublicMessage(_list.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.makePublicButton),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final token = await _service.ensurePublicShareToken(_list);
      if (!mounted) return;
      if (!_list.isPublic) {
        setState(() => _list = _list.copyWith(isPublic: true));
      }
      await showListShareSheet(context, list: _list, shareToken: token);
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

  void _openBookDetail(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
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
    final l = AppLocalizations.of(context)!;
    final gradientColors = _list.gradientColors;

    return Scaffold(
      body: ConstrainedContent(
        child: CustomScrollView(
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
                icon: const Icon(LucideIcons.share2, color: Colors.white),
                tooltip: l.share,
                onPressed: _shareList,
              ),
              if (_isOwner) ...[
                IconButton(
                  icon: const Icon(LucideIcons.pencil, color: Colors.white),
                  tooltip: l.editButton,
                  onPressed: _editList,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, color: Colors.white),
                  tooltip: l.deleteButton,
                  onPressed: _deleteList,
                ),
              ],
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
                    l.nBooks(_list.bookCount),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  if (!_isOwner && _ownerName != null) ...[
                    const Spacer(),
                    Text(
                      l.listByOwner(_ownerName!),
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
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
                    onRemove: _isOwner ? () => _removeBook(book) : null,
                    onTap: () => _openBookDetail(book),
                  );
                },
                childCount: _list.books.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      ),
      floatingActionButton: !_isOwner
          ? null
          : FloatingActionButton.extended(
        onPressed: _addBooks,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: Text(l.addBookToList),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l = AppLocalizations.of(context)!;
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
            l.noBooksInList,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l.addBooksFromLibrary,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
          if (_isOwner) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addBooks,
              icon: const Icon(LucideIcons.plus),
              label: Text(l.addBookToList),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomBookListItem extends StatelessWidget {
  final Book book;
  final Color gradientColor;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _CustomBookListItem({
    required this.book,
    required this.gradientColor,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final remove = onRemove;
    if (remove == null) return _buildRow(context);
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
                title: Text(l.removeBookTitle),
                content: Text(l.removeBookMessage(book.title)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(l.removeButton),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => remove(),
      child: _buildRow(context),
    );
  }

  Widget _buildRow(BuildContext context) {
    return InkWell(
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
              isbn: book.isbn,
              googleId: book.googleId,
              title: book.title,
              author: book.author,
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

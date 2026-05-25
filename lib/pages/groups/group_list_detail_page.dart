import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../models/reading_group.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';
import '../../services/groups_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import '../books/user_books_page.dart';

const _kSageGreen = Color(0xFF6B988D);

/// Page d'une bibliothèque (liste de lecture) de club, avec ses livres.
class GroupListDetailPage extends StatefulWidget {
  final String groupId;
  final GroupReadingList list;
  final bool isAdmin;
  final bool isMember;

  const GroupListDetailPage({
    super.key,
    required this.groupId,
    required this.list,
    required this.isAdmin,
    required this.isMember,
  });

  @override
  State<GroupListDetailPage> createState() => _GroupListDetailPageState();
}

class _GroupListDetailPageState extends State<GroupListDetailPage> {
  final GroupsService _service = GroupsService();
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _books = [];

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final books = await _service.getGroupListBooks(widget.list.id);
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _onAddBook() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBookSheet(listId: widget.list.id),
    );
    if (added == true) _load();
  }

  Future<void> _onRemoveBook(Map<String, dynamic> bookRow) async {
    final l = AppLocalizations.of(context);
    final addedBy = bookRow['added_by'] as String?;
    final canRemove =
        widget.isAdmin || (addedBy != null && addedBy == _currentUserId);
    if (!canRemove) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.groupLibraryRemoveBook),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeBookFromGroupList(
        listId: widget.list.id,
        bookId: (bookRow['id'] as num).toInt(),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _openBook(Map<String, dynamic> bookRow) {
    try {
      final book = Book.fromJson(Map<String, dynamic>.from(bookRow));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
      );
    } catch (e) {
      debugPrint('Erreur ouverture livre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).scaffoldBackgroundColor : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          widget.list.title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const BackButton(),
      ),
      floatingActionButton: widget.isMember
          ? FloatingActionButton(
              onPressed: _onAddBook,
              backgroundColor: _kSageGreen,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: ConstrainedContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _books.isEmpty
                    ? _buildEmptyState(l)
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.55,
                        ),
                        itemCount: _books.length,
                        itemBuilder: (_, i) {
                          final book = _books[i];
                          return _BookTile(
                            book: book,
                            onTap: () => _openBook(book),
                            onLongPress: () => _onRemoveBook(book),
                            isDark: isDark,
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.collections_bookmark_outlined,
            size: 64, color: Colors.black.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            l.groupLibraryListEmpty,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l.groupLibraryListEmptyHint,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Book tile
// ─────────────────────────────────────────────────────────────────────

class _BookTile extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isDark;

  const _BookTile({
    required this.book,
    required this.onTap,
    required this.onLongPress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final cover = book['cover_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedBookCover(
                imageUrl: cover,
                title: title,
                author: author,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (author.isNotEmpty)
            Text(
              author,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Add-book bottom sheet (Google Books search)
// ─────────────────────────────────────────────────────────────────────

class _AddBookSheet extends StatefulWidget {
  final int listId;
  const _AddBookSheet({required this.listId});

  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _searchCtrl = TextEditingController();
  final _booksService = BooksService();
  final _googleBooksService = GoogleBooksService();
  final _service = GroupsService();
  Timer? _debounce;
  bool _searching = false;
  int? _addingIndex;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final books = await _googleBooksService.searchBooks(q);
      if (!mounted) return;
      setState(() {
        _results = books
            .map((b) => <String, dynamic>{
                  'title': b.title,
                  'author': b.authorsString,
                  'isbn': b.isbn13,
                  'cover_url': b.coverUrl,
                  'page_count': b.pageCount,
                  'description': b.description,
                  'google_id': b.id,
                  'publisher': b.publisher,
                  'language': b.language ?? 'fr',
                  'published_date': b.publishedDate,
                })
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _addToList(int index) async {
    if (_addingIndex != null) return;
    setState(() => _addingIndex = index);
    try {
      final r = _results[index];
      final bookId = await _booksService.insertBookIfNotExists(
        title: r['title'] as String? ?? '',
        author: r['author'] as String? ?? r['authors']?.toString() ?? '',
        isbn: r['isbn'] as String?,
        coverUrl: r['cover_url'] as String? ?? r['thumbnail'] as String?,
        pageCount: (r['page_count'] as num?)?.toInt() ??
            (r['pageCount'] as num?)?.toInt(),
        description: r['description'] as String?,
        googleId: r['google_id'] as String? ?? r['id'] as String?,
        source: 'google_books',
        publisher: r['publisher'] as String?,
        language: r['language'] as String? ?? 'fr',
        publishedDate: r['published_date'] as String? ??
            r['publishedDate'] as String?,
      );
      await _service.addBookToGroupList(listId: widget.listId, bookId: bookId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _addingIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  l.groupLibraryAddBook,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: l.groupLibraryAddBookFromSearch,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          final cover = r['cover_url'] as String? ??
                              r['thumbnail'] as String?;
                          final title = r['title'] as String? ?? '';
                          final author = r['author'] as String? ??
                              (r['authors'] is List
                                  ? (r['authors'] as List).join(', ')
                                  : r['authors']?.toString() ?? '');
                          final isAdding = _addingIndex == i;
                          return ListTile(
                            leading: SizedBox(
                              width: 36,
                              height: 54,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedBookCover(
                                  imageUrl: cover,
                                  title: title,
                                  author: author,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 12),
                            ),
                            trailing: isAdding
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_circle_outline,
                                    color: _kSageGreen),
                            onTap: () => _addToList(i),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

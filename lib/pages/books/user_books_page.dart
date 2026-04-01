import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import '../../l10n/app_localizations.dart';
import '../../services/books_service.dart';
import '../../services/badges_service.dart';
import '../../widgets/badge_unlocked_dialog.dart';
import '../../models/book.dart';
import '../../models/user_custom_list.dart';
import '../../services/reading_session_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../models/reading_session.dart';
import '../reading/start_reading_session_page_unified.dart';
import '../reading/active_reading_session_page.dart';
import '../reading/end_reading_session_page.dart';
import '../reading/book_finished_share_service.dart';
import '../reading/book_completed_summary_page.dart';
import '../curated_lists/create_custom_list_dialog.dart';
import '../curated_lists/custom_list_detail_page.dart';
import '../curated_lists/add_book_to_list_page.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import '../../theme/app_theme.dart';
import '../../models/annotation_model.dart';
import '../../models/feature_flags.dart';
import '../../models/reading_sheet.dart';
import '../../services/annotation_service.dart';
import '../../services/ai_service.dart';
import '../../services/notion_service.dart';
import '../profile/upgrade_page.dart';
import 'reading_sheet_share_service.dart';

class UserBooksPage extends StatefulWidget {
  const UserBooksPage({super.key});

  @override
  State<UserBooksPage> createState() => _UserBooksPageState();
}

class _UserBooksPageState extends State<UserBooksPage> {
  final BooksService _booksService = BooksService();
  final ReadingSessionService _sessionService = ReadingSessionService();
  final UserCustomListsService _listsService = UserCustomListsService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _booksWithStatus = [];
  List<UserCustomList> _userLists = [];
  Map<String, double> _readingProgress = {};
  bool _isLoading = true;
  String _activeFilter = 'all';
  bool _luGridView = true;
  bool _showSearch = false;
  String _searchQuery = '';

  static const int _pageSize = 100;

  static const _placeholderColors = [
    Color(0xFF6B988D),
    Color(0xFFC6A85A),
    Color(0xFF8B7355),
    Color(0xFF9B6B8E),
    Color(0xFF6B7D9B),
    Color(0xFFB07D62),
    Color(0xFF7B9B6B),
    Color(0xFF9B8B6B),
  ];

  List<Map<String, dynamic>> get _filteredBooks {
    if (_searchQuery.isEmpty) return _booksWithStatus;
    final query = _searchQuery.toLowerCase();
    return _booksWithStatus.where((item) {
      final book = item['book'] as Book;
      return book.title.toLowerCase().contains(query) ||
          (book.author ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _readingBooksData => _filteredBooks
      .where((item) =>
          item['status'] == 'reading' || item['status'] == 'to_read')
      .toList();

  List<Map<String, dynamic>> get _finishedBooksData =>
      _filteredBooks.where((item) => item['status'] == 'finished').toList();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadBooks(),
        _loadLists(),
      ]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBooks() async {
    try {
      final booksWithStatus =
          await _booksService.getUserBooksWithStatusPaginated(
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() => _booksWithStatus = booksWithStatus);
      }

      _loadReadingProgress();
      _autoEnrichCovers();
      _autoEnrichDescriptions();
      _autoEnrichGenres();
    } catch (e) {
      debugPrint('Erreur _loadBooks: $e');
    }
  }

  Future<void> _loadLists() async {
    try {
      final lists = await _listsService.getUserListsWithBooks();
      if (mounted) setState(() => _userLists = lists);
    } catch (e) {
      debugPrint('Erreur _loadLists: $e');
    }
  }

  Future<void> _loadReadingProgress() async {
    final reading = _readingBooksData;
    final Map<String, double> progress = {};

    for (final item in reading) {
      final book = item['book'] as Book;
      if (book.pageCount == null || book.pageCount == 0) continue;
      try {
        final stats =
            await _sessionService.getBookStats(book.id.toString());
        if (stats.currentPage != null) {
          progress[book.id.toString()] =
              (stats.currentPage! / book.pageCount!).clamp(0.0, 1.0);
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _readingProgress = progress);
  }

  Future<void> _autoEnrichCovers() async {
    final hasMissing =
        _booksWithStatus.any((item) => (item['book'] as Book).coverUrl == null);
    if (!hasMissing) return;
    try {
      final count = await _booksService.enrichMissingCovers();
      if (count > 0 && mounted) _loadBooks();
    } catch (e) {
      debugPrint('Erreur auto-enrichissement couvertures: $e');
    }
  }

  Future<void> _autoEnrichDescriptions() async {
    final hasMissing = _booksWithStatus.any((item) {
      final d = (item['book'] as Book).description;
      return d == null || d.isEmpty;
    });
    if (!hasMissing) return;
    try {
      final count = await _booksService.enrichMissingDescriptions();
      if (count > 0 && mounted) _loadBooks();
    } catch (e) {
      debugPrint('Erreur auto-enrichissement descriptions: $e');
    }
  }

  Future<void> _autoEnrichGenres() async {
    final hasMissing =
        _booksWithStatus.any((item) => (item['book'] as Book).genre == null);
    if (!hasMissing) return;
    try {
      final count = await _booksService.enrichMissingGenres();
      if (count > 0 && mounted) _loadBooks();
    } catch (e) {
      debugPrint('Erreur auto-enrichissement genres: $e');
    }
  }

  void _navigateToBook(Book book, {bool isFinished = false}) {
    if (isFinished) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => BookCompletedSummaryPage(book: book)),
      ).then((_) => _loadAll());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => BookDetailPage(book: book)),
      ).then((_) => _loadAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = _isDark ? AppColors.bgDark : AppColors.libraryBg;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ConstrainedContent(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _booksWithStatus.isEmpty
                  ? _buildEmptyState(l10n)
                  : Column(
                      children: [
                        _buildHeaderWidget(l10n),
                        if (_showSearch) _buildSearchBarWidget(l10n),
                        _buildFilterPillsWidget(l10n),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadAll,
                            color: AppColors.sageGreen,
                            child: CustomScrollView(
                              slivers: [
                                ..._buildContent(l10n),
                                const SliverToBoxAdapter(
                                    child: SizedBox(height: 100)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bookOpen, size: 64,
              color: AppColors.sageGreen.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(l10n.noBooksInLibrary,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l10n.scanOrSyncBooks,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: _isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHeaderWidget(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: Icon(LucideIcons.arrowLeft,
                  color: _isDark ? AppColors.textPrimaryDark : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.libraryTitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isDark ? AppColors.textPrimaryDark : Colors.black,
                    )),
                Text(l10n.librarySubtitle.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: AppColors.sageGreen,
                    )),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _showSearch ? LucideIcons.x : LucideIcons.search,
              color: AppColors.sageGreen,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              _luGridView ? LucideIcons.layoutGrid : LucideIcons.list,
              color: AppColors.sageGreen,
            ),
            onPressed: () => setState(() => _luGridView = !_luGridView),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarWidget(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.searchBook,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  })
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              borderSide: BorderSide(
                  color: _isDark ? AppColors.borderDark : AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              borderSide:
                  const BorderSide(color: AppColors.sageGreen, width: 2)),
          filled: true,
          fillColor: _isDark ? AppColors.surfaceDark : Colors.white,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildFilterPillsWidget(AppLocalizations l10n) {
    final filters = [
      ('all', l10n.filterAll),
      ('reading', l10n.filterReading),
      ('finished', l10n.filterRead),
      ('lists', l10n.filterMyLists),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: filters.length,
          itemBuilder: (context, i) {
            final (key, label) = filters[i];
            final isActive = _activeFilter == key;
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.sageGreen
                      : (_isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isActive
                        ? AppColors.sageGreen
                        : (_isDark
                            ? AppColors.borderDark
                            : AppColors.sageGreen.withValues(alpha: 0.3)),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : AppColors.sageGreen,
                  ),
                ),
              ),
            );
          },
        ),
    );
  }

  List<Widget> _buildContent(AppLocalizations l10n) {
    switch (_activeFilter) {
      case 'reading':
        return _buildReadingSectionFull(l10n);
      case 'finished':
        return _buildFinishedSectionFull(l10n);
      case 'lists':
        return _buildListsSectionFull(l10n);
      default:
        return [
          if (_readingBooksData.isNotEmpty) ..._buildReadingSection(l10n),
          if (_finishedBooksData.isNotEmpty) ..._buildFinishedSection(l10n),
          if (_userLists.isNotEmpty) ..._buildListsSection(l10n),
        ];
    }
  }

  Widget _sectionHeader({
    required String title,
    required int count,
    VoidCallback? onSeeAll,
    Widget? trailing,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
        child: Row(
          children: [
            Text(title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDark ? AppColors.textPrimaryDark : Colors.black,
                )),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sageGreen,
                  )),
            ),
            const Spacer(),
            if (trailing != null) trailing,
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Row(
                  children: [
                    Text(AppLocalizations.of(context).seeAll,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.sageGreen,
                        )),
                    const SizedBox(width: 2),
                    const Icon(LucideIcons.arrowRight,
                        size: 14, color: AppColors.sageGreen),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // "En cours" section
  List<Widget> _buildReadingSection(AppLocalizations l10n) {
    return [
      _sectionHeader(
        title: l10n.currentlyReading,
        count: _readingBooksData.length,
        onSeeAll: () => _pushSeeAll(
            l10n.allReadingBooks, _readingBooksData, false),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _readingBooksData.length,
            itemBuilder: (context, i) {
              final book = _readingBooksData[i]['book'] as Book;
              final progress =
                  _readingProgress[book.id.toString()] ?? 0.0;
              return _buildReadingCard(book, progress);
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildReadingSectionFull(AppLocalizations l10n) {
    if (_readingBooksData.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(l10n.noCurrentlyReading,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      color: _isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
            ),
          ),
        ),
      ];
    }
    return [
      _sectionHeader(
          title: l10n.currentlyReading,
          count: _readingBooksData.length),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _readingBooksData.length,
            itemBuilder: (context, i) {
              final book = _readingBooksData[i]['book'] as Book;
              final progress =
                  _readingProgress[book.id.toString()] ?? 0.0;
              return _buildReadingCard(book, progress);
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildReadingCard(Book book, double progress) {
    return GestureDetector(
      onTap: () => _navigateToBook(book),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookCover(book, 140, 200),
            const SizedBox(height: 6),
            Text(book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isDark ? AppColors.textPrimaryDark : Colors.black87,
                )),
            if (book.author != null && book.author!.isNotEmpty)
              Text(book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: _isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  )),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: _isDark
                    ? AppColors.borderDark
                    : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.sageGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "Lu" section
  List<Widget> _buildFinishedSection(AppLocalizations l10n) {
    final books = _finishedBooksData.take(9).toList();
    return [
      _sectionHeader(
        title: l10n.readBooks,
        count: _finishedBooksData.length,
        onSeeAll: () => _pushSeeAll(
            l10n.allFinishedBooks, _finishedBooksData, true),
        trailing: IconButton(
          icon: Icon(
            _luGridView ? LucideIcons.layoutGrid : LucideIcons.list,
            size: 18,
            color: AppColors.sageGreen,
          ),
          onPressed: () => setState(() => _luGridView = !_luGridView),
          visualDensity: VisualDensity.compact,
        ),
      ),
      if (_luGridView)
        _buildFinishedGrid(books)
      else
        _buildFinishedList(books),
    ];
  }

  List<Widget> _buildFinishedSectionFull(AppLocalizations l10n) {
    if (_finishedBooksData.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(l10n.noReadBooks,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      color: _isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
            ),
          ),
        ),
      ];
    }
    return [
      _sectionHeader(
        title: l10n.readBooks,
        count: _finishedBooksData.length,
        trailing: IconButton(
          icon: Icon(
            _luGridView ? LucideIcons.layoutGrid : LucideIcons.list,
            size: 18,
            color: AppColors.sageGreen,
          ),
          onPressed: () => setState(() => _luGridView = !_luGridView),
          visualDensity: VisualDensity.compact,
        ),
      ),
      if (_luGridView)
        _buildFinishedGrid(_finishedBooksData)
      else
        _buildFinishedList(_finishedBooksData),
    ];
  }

  Widget _buildFinishedGrid(List<Map<String, dynamic>> books) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final book = books[i]['book'] as Book;
            return GestureDetector(
              onTap: () => _navigateToBook(book, isFinished: true),
              child: _buildBookCover(book, double.infinity, double.infinity),
            );
          },
          childCount: books.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
      ),
    );
  }

  Widget _buildFinishedList(List<Map<String, dynamic>> books) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final book = books[i]['book'] as Book;
          return ListTile(
            leading: CachedBookCover(
              imageUrl: book.coverUrl,
              isbn: book.isbn,
              googleId: book.googleId,
              title: book.title,
              author: book.author,
              width: 45,
              height: 65,
              borderRadius: BorderRadius.circular(6),
            ),
            title: Text(book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: book.author != null
                ? Text(book.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: _isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ))
                : null,
            trailing: const Icon(LucideIcons.chevronRight,
                size: 16, color: AppColors.sageGreen),
            onTap: () => _navigateToBook(book, isFinished: true),
          );
        },
        childCount: books.length,
      ),
    );
  }

  // "Mes listes" section
  List<Widget> _buildListsSection(AppLocalizations l10n) {
    final widgets = <Widget>[];
    for (final list in _userLists) {
      widgets.addAll(_buildSingleListRow(list));
    }
    return widgets;
  }

  List<Widget> _buildListsSectionFull(AppLocalizations l10n) {
    if (_userLists.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(l10n.noList,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      color: _isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
            ),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final list in _userLists) {
      widgets.addAll(_buildSingleListRow(list));
    }
    return widgets;
  }

  List<Widget> _buildSingleListRow(UserCustomList list) {
    return [
      _sectionHeader(
        title: list.title,
        count: list.bookCount,
        onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    CustomListDetailPage(list: list)),
          ).then((_) => _loadAll());
        },
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.books.length + 1,
            itemBuilder: (context, i) {
              if (i == list.books.length) {
                return _buildAddBookCard(list);
              }
              final book = list.books[i];
              return GestureDetector(
                onTap: () => _navigateToBook(book),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: _buildBookCover(book, 80, 120),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildAddBookCard(UserCustomList list) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddBookToListPage(
              listId: list.id,
              existingBookIds: list.books.map((b) => b.id).toSet(),
            ),
          ),
        ).then((_) => _loadAll());
      },
      child: Container(
        width: 80,
        height: 120,
        decoration: BoxDecoration(
          color: _isDark
              ? AppColors.surfaceDark
              : AppColors.sageGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.sageGreen.withValues(alpha: 0.3),
          ),
        ),
        child: const Center(
          child: Icon(LucideIcons.plus,
              size: 24, color: AppColors.sageGreen),
        ),
      ),
    );
  }

  Widget _buildBookCover(Book book, double width, double height) {
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      return Container(
        width: width.isFinite ? width : null,
        height: height.isFinite ? height : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedBookCover(
            imageUrl: book.coverUrl,
            isbn: book.isbn,
            googleId: book.googleId,
            title: book.title,
            author: book.author,
            width: width.isFinite ? width : 140,
            height: height.isFinite ? height : 200,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final color = _placeholderColors[
        book.title.hashCode.abs() % _placeholderColors.length];
    return Container(
      width: width.isFinite ? width : null,
      height: height.isFinite ? height : null,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )),
          if (book.author != null && book.author!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(book.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                )),
          ],
        ],
      ),
    );
  }

  void _pushSeeAll(
      String title, List<Map<String, dynamic>> books, bool isFinished) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SeeAllBooksPage(
          title: title,
          books: books,
          isFinished: isFinished,
          onReturn: _loadAll,
        ),
      ),
    );
  }
}

// ─── SEE ALL BOOKS PAGE ─────────────────────────────────

class _SeeAllBooksPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> books;
  final bool isFinished;
  final VoidCallback onReturn;

  const _SeeAllBooksPage({
    required this.title,
    required this.books,
    required this.isFinished,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.libraryBg,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18)),
        backgroundColor: isDark ? AppColors.bgDark : AppColors.libraryBg,
        elevation: 0,
      ),
      body: ConstrainedContent(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          itemBuilder: (context, i) {
            final book = books[i]['book'] as Book;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CachedBookCover(
                  imageUrl: book.coverUrl,
                  isbn: book.isbn,
                  googleId: book.googleId,
                  title: book.title,
                  author: book.author,
                  width: 45,
                  height: 65,
                  borderRadius: BorderRadius.circular(6),
                ),
                title: Text(book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: book.author != null
                    ? Text(book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ))
                    : null,
                trailing: const Icon(LucideIcons.chevronRight,
                    size: 16, color: AppColors.sageGreen),
                onTap: () {
                  if (isFinished) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BookCompletedSummaryPage(book: book)),
                    ).then((_) => onReturn());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BookDetailPage(book: book)),
                    ).then((_) => onReturn());
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// Page de détails avec sessions de lecture
class BookDetailPage extends StatefulWidget {
  final Book book;
  final String? initialStatus; // Optionnel, sera chargé si non fourni
  final String? sharedByUserId;

  const BookDetailPage({
    super.key,
    required this.book,
    this.initialStatus,
    this.sharedByUserId,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final BooksService _booksService = BooksService();
  final UserCustomListsService _customListsService = UserCustomListsService();
  final AnnotationService _annotationService = AnnotationService();
  final AiService _aiService = AiService();
  ReadingSession? _activeSession;
  BookReadingStats? _stats;
  List<Annotation> _annotations = [];
  int _remainingAiSummaries = -1;
  final Set<String> _summarizingIds = {};
  String? _bookStatus;
  String? _currentGenre;
  bool _isHidden = false;
  bool _isLoading = true;
  ReadingSheet? _readingSheet;
  bool _isGeneratingSheet = false;
  bool _isSyncingNotion = false;
  String? _playingAnnotationId;
  AudioPlayer? _annotationAudioPlayer;
  String? _coverUrl;

  // Shared-by banner
  String? _sharerName;

  static const List<String> _availableGenres = [
    'Roman',
    'Roman littéraire',
    'Science-Fiction',
    'Fantasy',
    'Thriller',
    'Policier',
    'Horreur',
    'Romance',
    'Biographie',
    'Histoire',
    'Historique',
    'Philosophie',
    'Développement personnel',
    'Psychologie',
    'Sciences',
    'Informatique',
    'Technologie',
    'Business',
    'Économie',
    'Politique',
    'Société',
    'Religion',
    'Art',
    'Musique',
    'Cuisine',
    'Santé',
    'Voyage',
    'Sport',
    'Jeunesse',
    'Young Adult',
    'BD / Comics',
    'Manga',
    'Poésie',
    'Humour',
    'Non-fiction',
  ];

  bool get _isBookFinished => _bookStatus == 'finished';

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.book.coverUrl;
    _loadSessionData();
    _loadSharerProfile();
  }

  Future<void> _loadSharerProfile() async {
    final uid = widget.sharedByUserId;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => _sharerName = row['display_name'] as String?);
      }
    } catch (e) {
      debugPrint('Error loading sharer profile: $e');
    }
  }

  @override
  void dispose() {
    _sessionService.dispose();
    _annotationAudioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _toggleAnnotationPlayback(Annotation annotation) async {
    if (_playingAnnotationId == annotation.id) {
      await _annotationAudioPlayer?.stop();
      setState(() => _playingAnnotationId = null);
    } else {
      _annotationAudioPlayer?.dispose();
      _annotationAudioPlayer = AudioPlayer();
      final url = _annotationService.getAudioUrl(annotation.audioPath!);
      await _annotationAudioPlayer!.setUrl(url);
      _annotationAudioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingAnnotationId = null);
        }
      });
      await _annotationAudioPlayer!.play();
      setState(() => _playingAnnotationId = annotation.id);
    }
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoading = true);

    try {
      final activeSession = await _sessionService.getActiveSession(widget.book.id.toString());
      final stats = await _sessionService.getBookStats(widget.book.id.toString());

      // Charger le statut du livre (utiliser initialStatus si fourni)
      String? status = widget.initialStatus;
      status ??= await _booksService.getBookStatus(widget.book.id);

      // Charger le statut de visibilité
      final userId = Supabase.instance.client.auth.currentUser?.id;
      bool hidden = false;
      if (userId != null) {
        final userBookData = await Supabase.instance.client
            .from('user_books')
            .select('is_hidden')
            .eq('user_id', userId)
            .eq('book_id', widget.book.id)
            .maybeSingle();
        hidden = userBookData?['is_hidden'] as bool? ?? false;
      }

      final annotations = await _annotationService
          .getAnnotationsForBook(widget.book.id.toString());
      final remainingSummaries = await _aiService.getRemainingAiSummaries();
      final cachedSheet = await _aiService.getCachedReadingSheet(widget.book.id);

      // Refresh cover URL from DB (may have been enriched in background)
      String? freshCoverUrl = widget.book.coverUrl;
      if (freshCoverUrl == null || freshCoverUrl.isEmpty) {
        try {
          final bookRow = await Supabase.instance.client
              .from('books')
              .select('cover_url')
              .eq('id', widget.book.id)
              .maybeSingle();
          freshCoverUrl = bookRow?['cover_url'] as String?;
        } catch (_) {}
      }

      setState(() {
        _activeSession = activeSession;
        _stats = stats;
        _annotations = annotations;
        _remainingAiSummaries = remainingSummaries;
        _readingSheet = cachedSheet;
        _bookStatus = status;
        _currentGenre = widget.book.genre;
        _isHidden = hidden;
        _coverUrl = freshCoverUrl;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur loadSessionData: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startReadingSession() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartReadingSessionPageUnified(book: widget.book),
      ),
    );

    // Si une session a été créée, naviguer vers la session active
    if (result != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveReadingSessionPage(
            activeSession: result,
            book: widget.book,
          ),
        ),
      );
      _loadSessionData();
    }
  }

  Future<void> _endReadingSession() async {
    if (_activeSession == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EndReadingSessionPage(
          activeSession: _activeSession!,
        ),
      ),
    );

    _loadSessionData();
  }

  Future<void> _removeFromLibrary() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromLibraryTitle),
        content: Text(l10n.removeFromLibraryMessage(widget.book.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeFromLibraryAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _booksService.removeBookFromLibrary(widget.book.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).bookRemovedFromLibrary)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleHidden() async {
    final newValue = !_isHidden;
    try {
      await _booksService.toggleBookHidden(widget.book.id, newValue);
      setState(() => _isHidden = newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? 'Livre masqué des autres utilisateurs'
                : 'Livre visible pour les autres utilisateurs'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGenrePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choisir le genre',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ..._availableGenres.map((genre) => ListTile(
                  leading: Icon(
                    _genreIcon(genre),
                    color: genre == _currentGenre
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                  title: Text(genre),
                  trailing: genre == _currentGenre
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    try {
                      await _booksService.updateBookGenre(
                          widget.book.id, genre);
                      if (mounted) setState(() => _currentGenre = genre);
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Erreur lors de la mise à jour')),
                      );
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  IconData _genreIcon(String genre) {
    const icons = {
      'Science-Fiction': Icons.rocket_launch,
      'Fantasy': Icons.auto_awesome,
      'Thriller': Icons.psychology,
      'Policier': Icons.search,
      'Horreur': Icons.nights_stay,
      'Romance': Icons.favorite,
      'Biographie': Icons.person,
      'Histoire': Icons.history_edu,
      'Historique': Icons.history_edu,
      'Philosophie': Icons.school,
      'Développement personnel': Icons.trending_up,
      'Psychologie': Icons.psychology_alt,
      'Sciences': Icons.science,
      'Informatique': Icons.computer,
      'Technologie': Icons.devices,
      'Business': Icons.show_chart,
      'Économie': Icons.show_chart,
      'Roman': Icons.auto_stories,
      'Roman littéraire': Icons.auto_stories,
      'BD / Comics': Icons.burst_mode,
      'Manga': Icons.burst_mode,
      'Poésie': Icons.edit_note,
      'Cuisine': Icons.restaurant,
      'Voyage': Icons.flight,
      'Humour': Icons.sentiment_very_satisfied,
      'Jeunesse': Icons.child_care,
      'Young Adult': Icons.child_care,
      'Non-fiction': Icons.menu_book,
      'Sport': Icons.sports,
      'Santé': Icons.health_and_safety,
      'Art': Icons.palette,
      'Musique': Icons.music_note,
      'Religion': Icons.church,
      'Politique': Icons.account_balance,
      'Société': Icons.groups,
    };
    return icons[genre] ?? Icons.bookmark;
  }

  Future<void> _openAmazonLink() async {
    final query = Uri.encodeComponent(
      '${widget.book.title} ${widget.book.author ?? ''}'.trim(),
    );
    final url = Uri.parse('https://www.amazon.fr/s?k=$query&i=stripbooks&tag=lexday-21');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showAddToListSheet() async {
    // Charger les listes et savoir lesquelles contiennent déjà ce livre
    final results = await Future.wait([
      _customListsService.getUserLists(),
      _customListsService.getListIdsContainingBook(widget.book.id),
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
        bookId: widget.book.id,
        service: _customListsService,
      ),
    );
  }

  Future<void> _markAsFinished() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('Terminer le livre'),
          ],
        ),
        content: const Text('Marquer ce livre comme terminé ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, terminé !'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _booksService.updateBookStatus(widget.book.id, 'finished');
        if (!mounted) return;

        setState(() => _bookStatus = 'finished');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livre marqué comme terminé !'),
            backgroundColor: Colors.green,
          ),
        );

        // Vérifier et attribuer les badges (livres terminés, etc.)
        try {
          final newBadges = await BadgesService().checkAndAwardBadges();
          if (newBadges.isNotEmpty && mounted) {
            for (final badge in newBadges) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => BadgeUnlockedDialog(badge: badge),
              );
            }
          }
        } catch (e) {
          debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatDuration(DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            icon: Icon(
              _isHidden ? Icons.visibility_off : Icons.visibility,
              color: _isHidden ? Colors.orange : null,
            ),
            tooltip: _isHidden ? 'Livre masqué aux autres' : 'Masquer ce livre',
            onPressed: _toggleHidden,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: AppLocalizations.of(context).removeFromLibraryTitle,
            onPressed: _removeFromLibrary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_sharerName != null) _buildSharedByBanner(),
            _buildBookHeader(),
            if (!_isLoading && _bookStatus != null) _buildReadingSessionSection(),
            if (_stats != null && _stats!.sessionsCount > 0) _buildStatsSection(),
            if (!_isLoading && widget.sharedByUserId == null) _buildAnnotationsSection(),
            if (!_isLoading && widget.sharedByUserId == null && _annotations.length >= 3) _buildReadingSheetSection(),
            if (widget.book.description != null) _buildDescriptionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedByBanner() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.sageGreen.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(LucideIcons.share2, size: 16, color: AppColors.sageGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.sharedByUser(_sharerName!),
              style: const TextStyle(
                color: AppColors.sageGreen,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedBookCover(
            imageUrl: _coverUrl,
            isbn: widget.book.isbn,
            googleId: widget.book.googleId,
            title: widget.book.title,
            author: widget.book.author,
            height: 180,
            width: 120,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.book.author != null && widget.book.author!.isNotEmpty && widget.book.author != 'Auteur inconnu')
                  Text(
                    widget.book.author!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      widget.book.isKindle ? Icons.cloud : Icons.camera_alt,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.book.isKindle ? 'Livre Kindle' : 'Livre scanné',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                if (widget.book.pageCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.book.pageCount} pages',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showGenrePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentGenre != null
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _currentGenre != null
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentGenre != null
                              ? _genreIcon(_currentGenre!)
                              : Icons.add,
                          size: 14,
                          color: _currentGenre != null
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentGenre ?? 'Ajouter un genre',
                          style: TextStyle(
                            fontSize: 12,
                            color: _currentGenre != null
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showAddToListSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
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
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openAmazonLink,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9900).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFF9900).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.shoppingCart,
                          size: 14,
                          color: Color(0xFFFF9900),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Acheter sur Amazon',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF9900),
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
    );
  }

  Widget _buildReadingSessionSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Session de lecture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_activeSession != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.shade900.withValues(alpha: 0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Lecture en cours...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Commencée à la page ${_activeSession!.startPage}'),
                      Text('Depuis ${_formatDuration(_activeSession!.startTime)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _endReadingSession,
                  icon: const Icon(Icons.stop),
                  label: const Text('Terminer cette lecture'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                if (!_isBookFinished) ...[
                  const Text(
                    'Suivez votre progression en prenant une photo ou en saisissant le numéro de page.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _startReadingSession,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Commencer une lecture'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _markAsFinished,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marquer comme terminé'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      foregroundColor: Colors.amber.shade800,
                      side: BorderSide(color: Colors.amber.shade600),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade100, Colors.orange.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Livre terminé !',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_stats != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        showBookFinishedShareSheet(
                          context: context,
                          book: widget.book,
                          stats: _stats!,
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Partager'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistiques de lecture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.menu_book,
                      value: '${_stats!.totalPagesRead}',
                      label: 'pages lues',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.schedule,
                      value: '${_stats!.totalMinutesRead}min',
                      label: 'de lecture',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.refresh,
                      value: '${_stats!.sessionsCount}',
                      label: 'sessions',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.speed,
                      value: _stats!.avgMinutesPerPage.toStringAsFixed(1),
                      label: 'min/page',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              if (_isBookFinished) ...[
                // Affichage pour livre terminé
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade100, Colors.orange.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Livre terminé !',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: Colors.green.shade600),
                    ],
                  ),
                ),
              ] else if (_stats!.currentPage != null) ...[
                // Affichage pour livre en cours
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Actuellement à la page ${_stats!.currentPage}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Annotations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_annotations.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_remainingAiSummaries >= 0 && _annotations.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$_remainingAiSummaries/${FeatureFlags.maxFreeAiSummaries} résumés restants',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (_annotations.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aucune annotation pour ce livre.\nAnnotez pendant vos sessions !',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_annotations.length, (index) {
                  final annotation = _annotations[index];
                  return _buildAnnotationCard(annotation, index);
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reading Sheet Section ──────────────────────────────────────────

  Widget _buildReadingSheetSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = FeatureFlags.isUnlocked(context, Feature.readingSheet);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.menu_book, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ma Fiche de Lecture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A54A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content based on state
              if (_isGeneratingSheet)
                _buildSheetLoadingState()
              else if (_readingSheet != null)
                _buildSheetContent(isDark)
              else
                _buildSheetCTA(isPremium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetCTA(bool isPremium) {
    return Column(
      children: [
        Text(
          'L\'IA analyse vos ${_annotations.length} annotations pour créer une fiche de lecture personnalisée : thèmes clés, citations marquantes, progression et synthèse.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: isPremium
              ? ElevatedButton.icon(
                  onPressed: () => _generateReadingSheet(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Générer ma fiche'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UpgradePage(
                          highlightedFeature: Feature.readingSheet,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Fonctionnalité Premium'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4A54A),
                    side: const BorderSide(color: Color(0xFFD4A54A)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSheetLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 12),
          Text(
            'L\'IA analyse vos ${_annotations.length} annotations...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent(bool isDark) {
    final sheet = _readingSheet!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Themes
        if (sheet.themes.isNotEmpty) ...[
          _buildSheetSubheader('Thèmes principaux', Icons.category_outlined),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sheet.themes.map((theme) {
              return Tooltip(
                message: theme.description,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    theme.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Theme descriptions
          const SizedBox(height: 8),
          ...sheet.themes.map((theme) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: '${theme.title} : ',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: theme.description),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
        ],

        // Quotes
        if (sheet.quotes.isNotEmpty) ...[
          _buildSheetSubheader('Citations marquantes', Icons.format_quote),
          const SizedBox(height: 8),
          ...sheet.quotes.map((quote) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(
                      color: Color(0xFFD4A54A),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '« ${quote.text} »',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (quote.page != null) ...[
                          Text(
                            'p. ${quote.page}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            quote.comment,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],

        // Progression
        if (sheet.progression.isNotEmpty) ...[
          _buildSheetSubheader('Progression de pensée', Icons.timeline),
          const SizedBox(height: 8),
          Text(
            sheet.progression,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Synthesis
        if (sheet.synthesis.isNotEmpty) ...[
          _buildSheetSubheader('Synthèse personnelle', Icons.lightbulb_outline),
          const SizedBox(height: 8),
          Text(
            sheet.synthesis,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _generateReadingSheet(force: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Régénérer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  showReadingSheetShareSheet(
                    context: context,
                    book: widget.book,
                    readingSheet: _readingSheet!,
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Partager'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),

        // Notion sync button
        FutureBuilder<bool>(
          future: NotionService().isConnected(),
          builder: (context, snapshot) {
            if (!(snapshot.data ?? false)) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSyncingNotion ? null : _syncToNotion,
                  icon: _isSyncingNotion
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined, size: 16),
                  label: Text(_isSyncingNotion ? 'Envoi en cours...' : 'Envoyer vers Notion'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSheetSubheader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Future<void> _generateReadingSheet({bool force = false}) async {
    if (!FeatureFlags.isUnlocked(context, Feature.readingSheet)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UpgradePage(
            highlightedFeature: Feature.readingSheet,
          ),
        ),
      );
      return;
    }

    setState(() => _isGeneratingSheet = true);
    try {
      final sheet = await _aiService.generateReadingSheet(
        widget.book.id,
        force: force,
      );
      if (mounted) {
        setState(() {
          _readingSheet = sheet;
          _isGeneratingSheet = false;
        });
      }
    } on AiPremiumRequiredException {
      if (mounted) {
        setState(() => _isGeneratingSheet = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UpgradePage(
              highlightedFeature: Feature.readingSheet,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingSheet = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncToNotion() async {
    setState(() => _isSyncingNotion = true);
    try {
      final notionUrl = await NotionService().syncReadingSheet(widget.book.id);
      if (mounted) {
        setState(() => _isSyncingNotion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fiche envoyée vers Notion !'),
            backgroundColor: Colors.green,
            action: notionUrl.isNotEmpty
                ? SnackBarAction(
                    label: 'Ouvrir',
                    textColor: Colors.white,
                    onPressed: () => launchUrl(Uri.parse(notionUrl)),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingNotion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildAnnotationCard(Annotation annotation, int index) {
    final dateStr = _formatAnnotationDate(annotation.createdAt);

    return Dismissible(
      key: Key(annotation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.delete, color: Colors.red.shade400),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer'),
            content:
                const Text('Supprimer cette annotation ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final removed = _annotations[index];
        setState(() => _annotations.removeAt(index));
        try {
          await _annotationService.deleteAnnotation(removed.id);
        } catch (e) {
          if (mounted) {
            setState(() => _annotations.insert(index, removed));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(top: index > 0 ? 8 : 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo thumbnail if applicable
            if (annotation.type == AnnotationType.photo &&
                annotation.imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _annotationService.getImageUrl(annotation.imagePath!),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Voice playback button
            if (annotation.type == AnnotationType.voice &&
                annotation.audioPath != null) ...[
              GestureDetector(
                onTap: () => _toggleAnnotationPlayback(annotation),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _playingAnnotationId == annotation.id
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Note vocale',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Content
            Text(
              annotation.content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            // AI Summary section
            if (annotation.aiSummary != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Résumé IA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _summarizeAnnotation(annotation),
                          child: Icon(Icons.refresh,
                              size: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      annotation.aiSummary!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (annotation.content.length >= 20) ...[
              const SizedBox(height: 8),
              _summarizingIds.contains(annotation.id)
                  ? const SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Résumé en cours...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _summarizeAnnotation(annotation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Résumer',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
            const SizedBox(height: 8),
            // Metadata row
            Row(
              children: [
                if (annotation.type == AnnotationType.voice) ...[
                  Icon(Icons.mic, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 2),
                  Text('Vocal', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(width: 12),
                ],
                if (annotation.pageNumber != null) ...[
                  Icon(Icons.bookmark_outline,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 2),
                  Text(
                    'p. ${annotation.pageNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                // Edit button
                GestureDetector(
                  onTap: () => _showEditAnnotationDialog(annotation),
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAnnotationDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _summarizeAnnotation(Annotation annotation) async {
    setState(() => _summarizingIds.add(annotation.id));
    try {
      final result = await _aiService.summarizeAnnotation(annotation.id);
      if (mounted) {
        setState(() {
          final idx = _annotations.indexWhere((a) => a.id == annotation.id);
          if (idx != -1) {
            _annotations[idx] =
                _annotations[idx].copyWith(aiSummary: result.summary);
          }
          _remainingAiSummaries = result.remaining;
        });
      }
    } on AiSummaryLimitReachedException {
      if (mounted) _showAiPaywall();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _summarizingIds.remove(annotation.id));
      }
    }
  }

  void _showAiPaywall() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Vous avez utilisé vos 3 résumés du mois',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Passez en Premium pour résumer tous vos passages sans limite',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UpgradePage(
                          highlightedFeature: Feature.aiSummary,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Découvrir Premium',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Réessayer le mois prochain',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditAnnotationDialog(Annotation annotation) {
    final contentController = TextEditingController(text: annotation.content);
    final pageController = TextEditingController(
      text: annotation.pageNumber?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'annotation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Contenu',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Page',
                prefixIcon: Icon(Icons.bookmark_outline, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = contentController.text.trim();
              if (newContent.isEmpty) return;

              Navigator.pop(context);

              try {
                final updated = await _annotationService.updateAnnotation(
                  annotation.id,
                  content: newContent,
                  pageNumber: int.tryParse(pageController.text),
                );
                if (mounted) {
                  setState(() {
                    final idx =
                        _annotations.indexWhere((a) => a.id == annotation.id);
                    if (idx != -1) _annotations[idx] = updated;
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.book.description!,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
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
      // Ajouter le livre à la liste nouvellement créée
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
          // Poignée
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

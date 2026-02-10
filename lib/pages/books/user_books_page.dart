import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/books_service.dart';
import '../../models/book.dart';
import '../../services/reading_session_service.dart';
import '../../models/reading_session.dart';
import '../reading/start_reading_session_page_unified.dart';
import '../reading/end_reading_session_page.dart';
import '../reading/book_finished_share_service.dart';
import '../../widgets/cached_book_cover.dart';

class UserBooksPage extends StatefulWidget {
  const UserBooksPage({super.key});

  @override
  State<UserBooksPage> createState() => _UserBooksPageState();
}

class _UserBooksPageState extends State<UserBooksPage> {
  final BooksService _booksService = BooksService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _booksWithStatus = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isEnrichingGenres = false;
  bool _isEnrichingAuthors = false;
  String _viewMode = 'status'; // 'status' ou 'genre'
  String? _selectedGenre; // null = tous les genres

  static const int _pageSize = 30;
  int _currentOffset = 0;

  // Livres séparés par statut
  List<Map<String, dynamic>> get _readingBooksData => _booksWithStatus
      .where((item) => item['status'] == 'reading' || item['status'] == 'to_read')
      .toList();

  List<Map<String, dynamic>> get _finishedBooksData => _booksWithStatus
      .where((item) => item['status'] == 'finished')
      .toList();

  Map<String, List<Map<String, dynamic>>> get _booksByGenre {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _booksWithStatus) {
      final book = item['book'] as Book;
      final genre = book.genre ?? 'Autre';
      grouped.putIfAbsent(genre, () => []);
      grouped[genre]!.add(item);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Autre') return 1;
        if (b == 'Autre') return -1;
        return a.compareTo(b);
      });
    return Map.fromEntries(
      sortedKeys.map((k) => MapEntry(k, grouped[k]!)),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBooks();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreBooks();
    }
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      final booksWithStatus = await _booksService.getUserBooksWithStatusPaginated(
        limit: _pageSize,
        offset: 0,
      );

      setState(() {
        _booksWithStatus = booksWithStatus;
        _isLoading = false;
        _hasMore = booksWithStatus.length >= _pageSize;
        _currentOffset = booksWithStatus.length;
      });

      // Enrichir automatiquement les données manquantes en arrière-plan
      _autoEnrichCovers();
      _autoEnrichDescriptions();
    } catch (e) {
      debugPrint('Erreur _loadBooks: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Enrichit automatiquement les couvertures manquantes sans bloquer l'UI
  Future<void> _autoEnrichCovers() async {
    final hasMissing = _booksWithStatus.any((item) {
      final coverUrl = (item['book'] as Book).coverUrl;
      return coverUrl == null || coverUrl.isEmpty;
    });

    if (!hasMissing) return;

    try {
      final count = await _booksService.enrichMissingCovers();
      if (count > 0 && mounted) {
        final booksWithStatus = await _booksService.getUserBooksWithStatusPaginated(
          limit: _pageSize,
          offset: 0,
        );
        setState(() {
          _booksWithStatus = booksWithStatus;
          _currentOffset = booksWithStatus.length;
        });
      }
    } catch (e) {
      debugPrint('Erreur auto-enrichissement couvertures: $e');
    }
  }

  /// Enrichit automatiquement les descriptions manquantes sans bloquer l'UI
  Future<void> _autoEnrichDescriptions() async {
    // Vérifier s'il y a des livres sans description
    final hasMissing = _booksWithStatus.any((item) {
      final description = (item['book'] as Book).description;
      return description == null || description.isEmpty;
    });

    if (!hasMissing) return;

    try {
      final count = await _booksService.enrichMissingDescriptions();
      if (count > 0 && mounted) {
        // Recharger les livres pour afficher les nouvelles descriptions
        final booksWithStatus = await _booksService.getUserBooksWithStatusPaginated(
          limit: _pageSize,
          offset: 0,
        );
        setState(() {
          _booksWithStatus = booksWithStatus;
          _currentOffset = booksWithStatus.length;
        });
      }
    } catch (e) {
      debugPrint('Erreur auto-enrichissement descriptions: $e');
    }
  }

  Future<void> _loadMoreBooks() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final moreBooks = await _booksService.getUserBooksWithStatusPaginated(
        limit: _pageSize,
        offset: _currentOffset,
      );

      setState(() {
        _booksWithStatus.addAll(moreBooks);
        _isLoadingMore = false;
        _hasMore = moreBooks.length >= _pageSize;
        _currentOffset += moreBooks.length;
      });
    } catch (e) {
      debugPrint('Erreur _loadMoreBooks: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  /// Alias pour compatibilité avec le code existant
  Future<void> _loadAllBooks() => _loadBooks();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Ma Bibliothèque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllBooks,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _booksWithStatus.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBooks,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'status',
                              label: Text('Statut'),
                              icon: Icon(Icons.playlist_add_check),
                            ),
                            ButtonSegment(
                              value: 'genre',
                              label: Text('Genre'),
                              icon: Icon(Icons.category),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (newSelection) {
                            setState(() => _viewMode = newSelection.first);
                          },
                        ),
                      ),
                      Expanded(
                        child: _viewMode == 'status'
                            ? _buildBooksListWithSections()
                            : _buildBooksListByGenre(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucun livre dans votre bibliothèque'),
          const SizedBox(height: 8),
          Text(
            'Scannez une couverture ou synchronisez vos livres Kindle',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _enrichGenres() async {
    setState(() => _isEnrichingGenres = true);
    try {
      final count = await _booksService.enrichMissingGenres();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? '$count livre${count > 1 ? 's' : ''} classifié${count > 1 ? 's' : ''}'
                : 'Aucun genre trouvé'),
          ),
        );
        if (count > 0) _loadAllBooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la classification')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnrichingGenres = false);
    }
  }

  Future<void> _enrichAuthors() async {
    setState(() => _isEnrichingAuthors = true);
    try {
      final count = await _booksService.enrichMissingAuthors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? 'Auteur trouvé pour $count livre${count > 1 ? 's' : ''}'
                : 'Aucun auteur trouvé'),
          ),
        );
        if (count > 0) _loadAllBooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la recherche des auteurs')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnrichingAuthors = false);
    }
  }

  bool get _hasBooksWithoutAuthor => _booksWithStatus.any(
    (item) {
      final author = (item['book'] as Book).author;
      return author == null || author.isEmpty || author == 'Auteur inconnu';
    },
  );

  Widget _buildEnrichAuthorsButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: OutlinedButton.icon(
        onPressed: _isEnrichingAuthors ? null : _enrichAuthors,
        icon: _isEnrichingAuthors
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_search),
        label: Text(_isEnrichingAuthors
            ? 'Recherche en cours...'
            : 'Rechercher les auteurs manquants'),
      ),
    );
  }

  Widget _buildGenreChips() {
    final grouped = _booksByGenre;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: _selectedGenre == null,
              label: Text('Tous (${_booksWithStatus.length})'),
              avatar: _selectedGenre == null ? null : const Icon(Icons.library_books, size: 16),
              onSelected: (_) => setState(() => _selectedGenre = null),
            ),
          ),
          ...grouped.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  selected: _selectedGenre == entry.key,
                  label: Text('${entry.key} (${entry.value.length})'),
                  avatar: _selectedGenre == entry.key
                      ? null
                      : Icon(_genreIcon(entry.key), size: 16),
                  onSelected: (_) => setState(() {
                    _selectedGenre = _selectedGenre == entry.key ? null : entry.key;
                  }),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBooksListByGenre() {
    final grouped = _booksByGenre;
    final hasUnclassified = _booksWithStatus.any(
      (item) => (item['book'] as Book).genre == null,
    );

    // Filtrer si un genre est sélectionné
    final filteredEntries = _selectedGenre != null
        ? grouped.entries.where((e) => e.key == _selectedGenre)
        : grouped.entries;

    return Column(
      children: [
        _buildGenreChips(),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            controller: _scrollController,
            children: [
              if (_hasBooksWithoutAuthor) _buildEnrichAuthorsButton(),
              if (hasUnclassified && _selectedGenre == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: _isEnrichingGenres ? null : _enrichGenres,
                    icon: _isEnrichingGenres
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_isEnrichingGenres
                        ? 'Classification en cours...'
                        : 'Classifier les livres sans genre'),
                  ),
                ),
              for (final entry in filteredEntries) ...[
                if (_selectedGenre == null)
                  _buildSectionHeader(
                    entry.key,
                    _genreIcon(entry.key),
                    entry.value.length,
                  ),
                ...entry.value.map((item) {
                  final book = item['book'] as Book;
                  final status = item['status'] as String?;
                  return _buildBookCard(
                    book,
                    isFinished: status == 'finished',
                    isHidden: item['is_hidden'] as bool? ?? false,
                  );
                }),
              ],
              // Loading indicator
              if (_isLoadingMore || _hasMore)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator()
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBooksListWithSections() {
    return ListView(
      controller: _scrollController,
      children: [
        if (_hasBooksWithoutAuthor) _buildEnrichAuthorsButton(),
        // Section: En cours / À lire
        if (_readingBooksData.isNotEmpty) ...[
          _buildSectionHeader(
            'En cours',
            Icons.auto_stories,
            _readingBooksData.length,
          ),
          ..._readingBooksData.map((item) => _buildBookCard(
                item['book'] as Book,
                isHidden: item['is_hidden'] as bool? ?? false,
              )),
        ],

        // Section: Terminés
        if (_finishedBooksData.isNotEmpty) ...[
          _buildSectionHeader(
            'Terminés',
            Icons.check_circle,
            _finishedBooksData.length,
          ),
          ..._finishedBooksData.map((item) => _buildBookCard(
                item['book'] as Book,
                isFinished: true,
                isHidden: item['is_hidden'] as bool? ?? false,
              )),
        ],

        // Loading indicator
        if (_isLoadingMore || _hasMore)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          ),
      ],
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
      'Business / Économie': Icons.show_chart,
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
      'Autre': Icons.bookmark,
    };
    return icons[genre] ?? Icons.bookmark;
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Book book, {bool isFinished = false, bool isHidden = false}) {
    return Dismissible(
      key: Key('book_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce livre ?'),
            content: Text('Retirer "${book.title}" de votre bibliothèque ?'),
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
        ) ?? false;
      },
      onDismissed: (direction) async {
        await _booksService.removeBookFromLibrary(book.id);
        _loadAllBooks();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: Stack(
            children: [
              CachedBookCover(
                imageUrl: book.coverUrl,
                width: 50,
                height: 70,
                borderRadius: BorderRadius.circular(4),
              ),
              if (isFinished)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (isHidden)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility_off,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.author != null && book.author!.isNotEmpty && book.author != 'Auteur inconnu')
                Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (book.description != null && book.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  book.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    book.isKindle ? Icons.cloud : Icons.camera_alt,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    book.isKindle ? 'Kindle' : 'Scanné',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailPage(book: book),
              ),
            ).then((_) => _loadAllBooks());
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

  const BookDetailPage({
    super.key,
    required this.book,
    this.initialStatus,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final BooksService _booksService = BooksService();
  ReadingSession? _activeSession;
  BookReadingStats? _stats;
  String? _bookStatus;
  String? _currentGenre;
  bool _isHidden = false;
  bool _isLoading = true;

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
    _loadSessionData();
  }

  @override
  void dispose() {
    _sessionService.dispose();
    super.dispose();
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

      setState(() {
        _activeSession = activeSession;
        _stats = stats;
        _bookStatus = status;
        _currentGenre = widget.book.genre;
        _isHidden = hidden;
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

    // Si une session a été créée, recharger les données
    if (result != null) {
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
        if (mounted) {
          setState(() => _bookStatus = 'finished');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Livre marqué comme terminé !'),
              backgroundColor: Colors.green,
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
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBookHeader(),
            if (!_isLoading) _buildReadingSessionSection(),
            if (_stats != null && _stats!.sessionsCount > 0) _buildStatsSection(),
            if (widget.book.description != null) _buildDescriptionSection(),
          ],
        ),
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
            imageUrl: widget.book.coverUrl,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showGenrePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentGenre != null
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
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

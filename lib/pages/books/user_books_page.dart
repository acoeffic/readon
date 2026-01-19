import 'package:flutter/material.dart';
import '../../services/books_service.dart';
import '../../models/book.dart';
import '../../services/reading_session_service.dart';
import '../../models/reading_session.dart';
import '../reading/start_reading_session_page_unified.dart';
import '../reading/end_reading_session_page.dart';

class UserBooksPage extends StatefulWidget {
  const UserBooksPage({super.key});

  @override
  State<UserBooksPage> createState() => _UserBooksPageState();
}

class _UserBooksPageState extends State<UserBooksPage> {
  final BooksService _booksService = BooksService();
  List<Map<String, dynamic>> _booksWithStatus = [];
  bool _isLoading = true;

  // Livres séparés par statut
  List<Book> get _readingBooks => _booksWithStatus
      .where((item) => item['status'] == 'reading' || item['status'] == 'to_read')
      .map((item) => item['book'] as Book)
      .toList();

  List<Book> get _finishedBooks => _booksWithStatus
      .where((item) => item['status'] == 'finished')
      .map((item) => item['book'] as Book)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadAllBooks();
  }

  Future<void> _loadAllBooks() async {
    setState(() => _isLoading = true);

    try {
      final booksWithStatus = await _booksService.getUserBooksWithStatus();

      setState(() {
        _booksWithStatus = booksWithStatus;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur _loadAllBooks: $e');
      setState(() => _isLoading = false);
    }
  }

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
              : _buildBooksListWithSections(),
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

  Widget _buildBooksListWithSections() {
    return ListView(
      children: [
        // Section: En cours / À lire
        if (_readingBooks.isNotEmpty) ...[
          _buildSectionHeader(
            'En cours',
            Icons.auto_stories,
            _readingBooks.length,
          ),
          ..._readingBooks.map((book) => _buildBookCard(book)),
        ],

        // Section: Terminés
        if (_finishedBooks.isNotEmpty) ...[
          _buildSectionHeader(
            'Terminés',
            Icons.check_circle,
            _finishedBooks.length,
          ),
          ..._finishedBooks.map((book) => _buildBookCard(book, isFinished: true)),
        ],
      ],
    );
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
              color: Theme.of(context).primaryColor.withOpacity(0.1),
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

  Widget _buildBookCard(Book book, {bool isFinished = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Stack(
          children: [
            book.coverUrl != null && book.coverUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      book.coverUrl!,
                      width: 50,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.book, size: 50);
                      },
                    ),
                  )
                : const Icon(Icons.book, size: 50),
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
          ],
        ),
        title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null)
              Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          ).then((_) => _loadAllBooks()); // Recharger après retour
        },
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
  bool _isLoading = true;

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

      setState(() {
        _activeSession = activeSession;
        _stats = stats;
        _bookStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur loadSessionData: $e');
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
          if (widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.book.coverUrl!,
                height: 180,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    width: 120,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.book, size: 60),
                  );
                },
              ),
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
                if (widget.book.author != null)
                  Text(
                    widget.book.author!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      widget.book.isKindle ? Icons.cloud : Icons.camera_alt,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.book.isKindle ? 'Livre Kindle' : 'Livre scanné',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                if (widget.book.pageCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.book.pageCount} pages',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
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
                    color: Colors.blue.shade50,
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
                const Text(
                  'Suivez votre progression de lecture en photographiant les pages de début et de fin.',
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
            style: TextStyle(color: Colors.grey.shade700),
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

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
  List<Book> _allBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllBooks();
  }

  Future<void> _loadAllBooks() async {
    setState(() => _isLoading = true);
    
    try {
      final books = await _booksService.getUserBooks();
      
      setState(() {
        _allBooks = books;
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
          : _allBooks.isEmpty
              ? _buildEmptyState()
              : _buildBooksList(),
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

  Widget _buildBooksList() {
    return ListView.builder(
      itemCount: _allBooks.length,
      itemBuilder: (context, index) {
        final book = _allBooks[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: book.coverUrl != null && book.coverUrl!.isNotEmpty
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
              );
            },
          ),
        );
      },
    );
  }
}

// Page de détails avec sessions de lecture
class BookDetailPage extends StatefulWidget {
  final Book book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  ReadingSession? _activeSession;
  BookReadingStats? _stats;
  bool _isLoading = true;

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
      
      setState(() {
        _activeSession = activeSession;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur loadSessionData: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startReadingSession() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Utilisez le bouton flottant pour démarrer une session'),
      ),
    );
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
              if (_stats!.currentPage != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
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

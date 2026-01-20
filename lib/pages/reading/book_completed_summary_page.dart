// lib/pages/reading/book_completed_summary_page.dart
// Page de résumé affichée après avoir terminé un livre

import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../services/reading_session_service.dart';
import '../../services/suggestions_service.dart';
import '../../models/book_suggestion.dart';
import '../../widgets/suggestion_card.dart';

class BookCompletedSummaryPage extends StatefulWidget {
  final Book book;
  final ReadingSession? lastSession;

  const BookCompletedSummaryPage({
    super.key,
    required this.book,
    this.lastSession,
  });

  @override
  State<BookCompletedSummaryPage> createState() => _BookCompletedSummaryPageState();
}

class _BookCompletedSummaryPageState extends State<BookCompletedSummaryPage>
    with SingleTickerProviderStateMixin {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final SuggestionsService _suggestionsService = SuggestionsService();
  BookReadingStats? _stats;
  List<ReadingSession> _sessions = [];
  List<BookSuggestion> _suggestions = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sessionService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _sessionService.getBookStats(widget.book.id.toString());
      final sessions = await _sessionService.getBookSessions(widget.book.id.toString());

      // Charger les suggestions basées sur ce livre
      final suggestions = await _suggestionsService.getPersonalizedSuggestions(
        limit: 3,
        basedOnBook: widget.book,
      );

      setState(() {
        _stats = stats;
        _sessions = sessions.where((s) => s.endPage != null).toList();
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur loadData: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header avec animation
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          // Contenu
          SliverToBoxAdapter(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.shade400,
            Colors.orange.shade400,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // AppBar personnalisée
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Livre terminé',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),

            // Animation de félicitations
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  const Icon(
                    Icons.celebration,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Félicitations !',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vous avez terminé',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Couverture du livre
            Hero(
              tag: 'book_cover_${widget.book.id}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty
                      ? Image.network(
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
                        )
                      : Container(
                          height: 180,
                          width: 120,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.book, size: 60),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Titre et auteur
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.book.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.book.author != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.book.author!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistiques globales
          _buildStatsCard(),

          const SizedBox(height: 16),

          // Historique des sessions
          _buildSessionsHistory(),

          const SizedBox(height: 24),

          // Suggestions de lecture
          if (_suggestions.isNotEmpty) ...[
            _buildSuggestionsSection(),
            const SizedBox(height: 24),
          ],

          // Bouton retour
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.home),
            label: const Text('Retour à l\'accueil'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Vos statistiques',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats principales
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.menu_book,
                    value: '${_stats!.totalPagesRead}',
                    label: 'pages lues',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    icon: Icons.schedule,
                    value: _formatDuration(_stats!.totalMinutesRead),
                    label: 'de lecture',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.repeat,
                    value: '${_stats!.sessionsCount}',
                    label: 'sessions',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    icon: Icons.speed,
                    value: '${_stats!.avgMinutesPerPage.toStringAsFixed(1)} min',
                    label: 'par page',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            // Rythme de lecture
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Rythme de lecture : ${_stats!.readingPaceDescription}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsHistory() {
    if (_sessions.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Historique des sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Liste des sessions
            ...(_sessions.take(10).map((session) => _buildSessionItem(session))),

            if (_sessions.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${_sessions.length - 10} autres sessions',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Que lire ensuite ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Suggestions basées sur votre lecture',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Liste des suggestions
            ..._suggestions.map((suggestion) => SuggestionCard(
              suggestion: suggestion,
              onAddToLibrary: () async {
                final success = await _suggestionsService.addSuggestedBookToLibrary(suggestion);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${suggestion.book.title} ajouté à votre bibliothèque'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Retirer la suggestion de la liste
                  setState(() {
                    _suggestions.remove(suggestion);
                  });
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erreur lors de l\'ajout du livre'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(ReadingSession session) {
    final pagesRead = session.pagesRead;
    final duration = session.durationMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Date
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today,
              size: 20,
              color: Colors.deepPurple.shade700,
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(session.startTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pages ${session.startPage} → ${session.endPage}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Stats session
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '$pagesRead p.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '${duration}min',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

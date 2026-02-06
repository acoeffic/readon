import 'package:flutter/material.dart';
import '../../models/reading_session.dart';
import '../../models/book.dart';
import '../../services/reading_session_service.dart';
import '../../widgets/cached_book_cover.dart';
import 'session_detail_page.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _sessionsData = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSessions();
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
      _loadMoreSessions();
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
    });

    final data = await _sessionService.getSessionsPaginated(
      limit: _pageSize,
      offset: 0,
    );

    setState(() {
      _sessionsData = data;
      _isLoading = false;
      _hasMore = data.length >= _pageSize;
      _currentOffset = data.length;
    });
  }

  Future<void> _loadMoreSessions() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final data = await _sessionService.getSessionsPaginated(
      limit: _pageSize,
      offset: _currentOffset,
    );

    setState(() {
      _sessionsData.addAll(data);
      _isLoadingMore = false;
      _hasMore = data.length >= _pageSize;
      _currentOffset += data.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mes Sessions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessionsData.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: _buildSessionsList(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucune session de lecture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Lancez une session pour commencer !',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    final grouped = _groupSessionsByDate(_sessionsData);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.length + (_isLoadingMore || _hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the end
        if (index >= grouped.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }

        final group = grouped[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                group.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ...group.sessions.map((data) => _buildSessionCard(data)),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> data) {
    final session = ReadingSession.fromJson(data);
    final bookData = data['books'] as Map<String, dynamic>?;
    final book = bookData != null ? Book.fromJson(bookData) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final deleted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => SessionDetailPage(
                session: session,
                book: book,
              ),
            ),
          );
          if (deleted == true) {
            _loadSessions();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
          children: [
            // Cover du livre
            CachedBookCover(
              imageUrl: book?.coverUrl,
              width: 48,
              height: 68,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(width: 12),
            // Infos session
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book?.title ?? 'Livre inconnu',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (session.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'En cours',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.menu_book,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${session.pagesRead} pages',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(session.durationMinutes),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'p.${session.startPage}${session.endPage != null ? ' → p.${session.endPage}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            // Heure
            Text(
              _formatTime(session.startTime),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  List<_DateGroup> _groupSessionsByDate(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final data in sessions) {
      final startTime = DateTime.parse(data['start_time'] as String).toLocal();
      final sessionDate =
          DateTime(startTime.year, startTime.month, startTime.day);

      String key;
      if (sessionDate == today) {
        key = "Aujourd'hui";
      } else if (sessionDate == yesterday) {
        key = 'Hier';
      } else if (sessionDate.isAfter(thisWeekStart) ||
          sessionDate == thisWeekStart) {
        key = 'Cette semaine';
      } else if (sessionDate.month == now.month &&
          sessionDate.year == now.year) {
        key = 'Ce mois';
      } else {
        key = _formatMonthYear(sessionDate);
      }

      groups.putIfAbsent(key, () => []);
      groups[key]!.add(data);
    }

    // Conserver l'ordre d'insertion (les sessions sont déjà triées par date desc)
    return groups.entries
        .map((e) => _DateGroup(label: e.key, sessions: e.value))
        .toList();
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h${mins}min';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _DateGroup {
  final String label;
  final List<Map<String, dynamic>> sessions;

  _DateGroup({required this.label, required this.sessions});
}

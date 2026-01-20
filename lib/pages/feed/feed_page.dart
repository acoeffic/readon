// pages/feed/feed_page.dart
// Page principale du flux (Feed) avec activités des amis

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../feed/widgets/feed_header.dart';
import 'widgets/friend_activity_card.dart';
import '../feed/widgets/streak_card.dart';
import '../../services/streak_service.dart';
import '../../models/reading_streak.dart';
import 'streak_detail_page.dart';
import 'widgets/continue_reading_card.dart';
import '../../services/books_service.dart';
import '../../models/book.dart';
import '../reading/start_reading_session_page_unified.dart';
import '../reading/active_reading_session_page.dart';
import '../../services/suggestions_service.dart';
import '../../models/book_suggestion.dart';
import '../../widgets/suggestion_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final supabase = Supabase.instance.client;
  final streakService = StreakService();
  final booksService = BooksService();
  final suggestionsService = SuggestionsService();
  List<Map<String, dynamic>> friendActivities = [];
  ReadingStreak? currentStreak;
  Map<String, dynamic>? currentReadingBook;
  List<BookSuggestion> suggestions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  Future<void> loadFeed() async {
    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      // Charger le streak
      final streak = await streakService.getUserStreak();

      // Charger le dernier livre en cours
      final currentBook = await booksService.getCurrentReadingBook();

      // Charger les activités de tes amis via la fonction SQL
      final activitiesRes = await supabase.rpc('get_feed', params: {
        'p_user_id': user.id,
        'p_limit': 20,
        'p_offset': 0,
      });

      // Charger les suggestions personnalisées
      final suggestionsRes = await suggestionsService.getPersonalizedSuggestions(limit: 5);

      setState(() {
        currentStreak = streak;
        currentReadingBook = currentBook;
        friendActivities = List<Map<String, dynamic>>.from(activitiesRes ?? []);
        suggestions = suggestionsRes;
        loading = false;
      });
    } catch (e) {
      print('Erreur loadFeed: $e');
      setState(() => loading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadFeed,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.l),
            children: [
              const FeedHeader(),
              const SizedBox(height: AppSpace.l),

              // 👉 Continuer la lecture
              if (!loading && currentReadingBook != null) ...[
                ContinueReadingCard(
                  book: currentReadingBook!['book'] as Book,
                  currentPage: (currentReadingBook!['current_page'] as num).toInt(),
                  totalPages: currentReadingBook!['total_pages'] as int?,
                  onTap: () async {
                    final book = currentReadingBook!['book'] as Book;
                    final session = await Navigator.push<dynamic>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StartReadingSessionPageUnified(
                          book: book,
                        ),
                      ),
                    );
                    // Si une session a été créée, naviguer vers ActiveReadingSessionPage
                    if (session != null && mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveReadingSessionPage(
                            activeSession: session,
                            book: book,
                          ),
                        ),
                      );
                    }
                    // Rafraîchir le feed après la session
                    loadFeed();
                  },
                ),
                const SizedBox(height: AppSpace.l),
              ],

              // 👉 Streak de lecture
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (currentStreak != null)
                StreakCard(
                  streak: currentStreak!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StreakDetailPage(
                          initialStreak: currentStreak!,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: AppSpace.l),

              // 👉 Suggestions de lecture
              if (!loading && suggestions.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Suggestions pour toi",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                SuggestionsCarousel(
                  suggestions: suggestions,
                  onAddToLibrary: (suggestion) async {
                    final success = await suggestionsService.addSuggestedBookToLibrary(suggestion);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${suggestion.book.title} ajouté à votre bibliothèque'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      loadFeed(); // Rafraîchir pour retirer le livre des suggestions
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Erreur lors de l\'ajout du livre'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpace.l),
              ],

              // 👉 Activité des amis
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Activité de tes amis",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!loading && friendActivities.isNotEmpty)
                    TextButton(
                      onPressed: loadFeed,
                      child: const Text('Rafraîchir'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s),

              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (friendActivities.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Pas encore d\'activité',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajoutez des amis pour voir leurs lectures!',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...friendActivities.map((activity) => FriendActivityCard(activity: activity)),

            ],
          ),
        ),
      ),
    );
  }
}
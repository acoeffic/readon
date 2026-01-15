// pages/feed/feed_page.dart
// Page principale du flux (Feed) avec activités des amis

import 'package:flutter/material.dart';
import 'package:readon/pages/feed/widgets/action_chip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../feed/widgets/feed_header.dart';
import 'widgets/friend_activity_card.dart';
import '../feed/widgets/progress_card.dart';
import 'package:readon/pages/friends/friends_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> sessions = [];
  List<Map<String, dynamic>> friendActivities = [];
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

      // Charger tes sessions récentes
      final sessionRes = await supabase
          .from('reading_sessions')
          .select('*')
          .eq('user_id', user.id)
          .not('end_time', 'is', null)
          .order('created_at', ascending: false)
          .limit(1);

      // Récupérer les livres pour chaque session
final sessionsWithBooks = await Future.wait(
  (sessionRes as List).map((session) async {
    try {
      final sessionMap = session is Map<String, dynamic>
          ? session
          : Map<String, dynamic>.from(session as Map);
      
      final bookId = sessionMap['book_id'] as String;
      final book = await supabase
          .from('books')
          .select('*')
          .eq('id', int.parse(bookId))
          .maybeSingle();
      
      return {...sessionMap, 'book': book};
    } catch (e) {
      print('Erreur récupération livre: $e');
      return {...session as Map<String, dynamic>, 'book': null};
    }
  }),
);

      // Charger les activités de tes amis via la fonction SQL
      final activitiesRes = await supabase.rpc('get_feed', params: {
        'p_user_id': user.id,
        'p_limit': 20,
        'p_offset': 0,
      });

      setState(() {
        sessions = List<Map<String, dynamic>>.from(sessionsWithBooks);
        friendActivities = List<Map<String, dynamic>>.from(activitiesRes ?? []);
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

              // 👉 Dernières sessions
              Text(
                'Ta dernière lecture',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.s),

              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (sessions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.book_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Aucune lecture récente',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...sessions.map((session) {
                  final bookData = session['book'];
                  String bookTitle = 'Livre inconnu';
                  String bookAuthor = 'Auteur inconnu';
                  int? totalPages;
                  
                  if (bookData != null) {
                    final book = bookData is Map<String, dynamic> 
                        ? bookData 
                        : Map<String, dynamic>.from(bookData as Map);
                    
                    bookTitle = book['title']?.toString() ?? 'Livre inconnu';
                    bookAuthor = book['author']?.toString() ?? 'Auteur inconnu';
                    totalPages = (book['page_count'] as num?)?.toInt();
                  }
                  
                  final startPage = (session['start_page'] as num?)?.toInt();
                  final endPage = (session['end_page'] as num?)?.toInt();
                  
                  final pagesRead = (endPage != null && startPage != null) 
                      ? endPage - startPage 
                      : 0;
                  
                  final progress = (totalPages != null && totalPages > 0 && endPage != null)
                      ? (endPage / totalPages).clamp(0.0, 1.0)
                      : 0.0;

                  return ProgressCard(
                    bookTitle: bookTitle,
                    author: bookAuthor,
                    progress: progress,
                    currentPage: endPage,
                    totalPages: totalPages,
                    pagesRead: pagesRead,
                  );
                }),

              const SizedBox(height: AppSpace.xl),

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

              const SizedBox(height: AppSpace.xl),

              // Actions rapides
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ActionChipButton(
                    icon: Icons.book,
                    label: 'Découvrir des livres',
                    onTap: () {
                      // TODO: Navigate to discover page
                    },
                  ),
                  ActionChipButton(
                    icon: Icons.people,
                    label: 'Voir les amis',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsPage()),
                      );
                    },
                  ),
                  ActionChipButton(
                    icon: Icons.add,
                    label: 'Ajouter une lecture',
                    onTap: () {
                      // Le FAB global gère déjà ça
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Utilisez le bouton flottant pour démarrer une lecture'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
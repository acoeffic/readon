// pages/feed/feed_page.dart
// Page principale du flux (Feed) extraite du fichier monolithique

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_bar.dart';
import '../feed/widgets/feed_header.dart';
import '../feed/widgets/progress_card.dart';
import '../feed/widgets/friend_activity_card.dart';
import '../feed/widgets/action_chip.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> sessions = [];
  List<dynamic> friendActivities = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  Future<void> loadFeed() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final sessionRes = await supabase
          .from('reading_sessions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      final friendsRes = await supabase
          .from('friend_activity_view')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        sessions = sessionRes;
        friendActivities = friendsRes;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur lors du chargement')));
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
                'Tes dernières lectures',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.s),

              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (sessions.isEmpty)
                const Text('Aucune session trouvée')
              else
                ...sessions.map((s) => ProgressCard(session: s)),

              const SizedBox(height: AppSpace.xl),

              // 👉 Activité des amis
              Text(
                "Activité de tes amis",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.s),

              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (friendActivities.isEmpty)
                const Text("Pas encore d'activité")
              else
                ...friendActivities.map((a) => FriendActivityCard(activity: a)),

              const SizedBox(height: AppSpace.xl),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  ActionChipWidget(label: 'Découvrir des livres'),
                  ActionChipWidget(label: 'Voir les amis'),
                  ActionChipWidget(label: 'Ajouter une lecture'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
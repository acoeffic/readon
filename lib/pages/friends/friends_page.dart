import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'find_contacts_friends_page.dart';
import 'friend_requests_page.dart';
import 'search_users_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 FriendsPage initState appelé !');
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Non connecté';
        _loading = false;
      });
      return;
    }

    try {
      debugPrint('🔍 Chargement des amis pour user: ${user.id}');
      final data = await supabase.rpc('get_friends', params: {'uid': user.id});
      
      debugPrint('📦 Données brutes reçues: $data');
      debugPrint('📦 Type de données: ${data.runtimeType}');

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      debugPrint('✅ Nombre d\'amis trouvés: ${list.length}');
      debugPrint('📋 Liste des amis: $list');

      if (!mounted) return;
      setState(() {
        _friends = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors du chargement: $e';
        _loading = false;
      });
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.rpc('remove_friend', params: {
        'uid': user.id,
        'fid': friendId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ami retiré')),
      );

      await _loadFriends();
    } catch (e) {
      debugPrint('❌ Erreur suppression ami: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de retirer cet ami: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Mes amis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_phone, color: AppColors.primary),
            tooltip: 'Trouver des amis',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const FindContactsFriendsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchUsersPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(),

            if (_error != null && !_loading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: AppSpace.m),
                      Text(
                        _error!, 
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpace.m),
                      ElevatedButton(
                        onPressed: _loadFriends,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_loading && _friends.isEmpty && _error == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: AppSpace.m),
                      Text(
                        'Aucun ami trouvé', 
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpace.s),
                      Text(
                        'Ajoutez des amis pour voir leur activité !',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_loading && _friends.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
                  itemBuilder: (context, index) {
                    final f = _friends[index];
                    final name = f['display_name'] as String? ?? 'Utilisateur';
                    final email = f['email'] as String? ?? '';
                    final friendId = f['id'] as String? ?? '';

                    return Container(
                      padding: const EdgeInsets.all(AppSpace.m),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.accentDark
                                : AppColors.accentLight,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: AppSpace.m),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: AppSpace.xs),
                                Text(
                                  email, 
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: friendId.isEmpty
                                ? null
                                : () => _removeFriend(friendId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
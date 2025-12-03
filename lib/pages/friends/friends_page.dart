import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import 'friend_requests_page.dart';

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
      final data = await supabase.rpc('get_friends', params: {'uid': user.id});

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _friends = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors du chargement';
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de retirer cet ami')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BackHeader(title: 'Mes amis'),
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

              const SizedBox(height: AppSpace.m),

              if (_loading) const LinearProgressIndicator(),

              if (_error != null && !_loading)
                Expanded(
                  child: Center(
                    child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),

              if (!_loading && _friends.isEmpty && _error == null)
                Expanded(
                  child: Center(
                    child: Text('Aucun ami trouvé', style: Theme.of(context).textTheme.bodyMedium),
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
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.accentLight,
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
                                  Text(email, style: Theme.of(context).textTheme.bodyMedium),
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
      ),
    );
  }
}
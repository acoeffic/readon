import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../widgets/user_search_card.dart';
import '../../models/reading_group.dart';
import '../../models/user_search_result.dart';
import '../groups/group_detail_page.dart';
import 'friend_profile_page.dart';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _controller = TextEditingController();
  List<UserSearchResult> _userResults = [];
  List<ReadingGroup> _groupResults = [];
  Map<String, bool> _pendingRequests = {}; // user_id -> isPending
  bool _loading = false;
  int _selectedTab = 0; // 0 = Amis, 1 = Groupes

  Future<void> _search(String term) async {
    final query = term.trim();
    if (query.length < 2) {
      setState(() {
        _userResults = [];
        _groupResults = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final supabase = Supabase.instance.client;
    final pattern = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

    try {
      if (_selectedTab == 0) {
        // Recherche de base des utilisateurs
        final basicData = await supabase
            .from('profiles')
            .select('id, display_name, email')
            .or('display_name.ilike.$pattern,email.ilike.$pattern')
            .limit(20);

        if (!mounted) return;

        // Récupérer les données enrichies pour chaque utilisateur
        final enrichedUsers = <UserSearchResult>[];
        for (final user in (basicData as List)) {
          try {
            final userId = user['id'] as String;
            final displayName = user['display_name'] as String? ?? user['email'] as String? ?? 'Utilisateur';

            print('🔍 Récupération données pour: $displayName ($userId)');

            final enrichedData = await supabase.rpc(
              'get_user_search_data',
              params: {'p_user_id': userId},
            );

            print('📦 Données reçues pour $displayName: $enrichedData');

            if (enrichedData != null) {
              final userResult = UserSearchResult.fromJson(
                Map<String, dynamic>.from(enrichedData as Map),
              );
              print('✅ $displayName - isPrivate: ${userResult.isProfilePrivate}');
              enrichedUsers.add(userResult);
            } else {
              print('⚠️ enrichedData est NULL pour $displayName');
            }
          } catch (e, stackTrace) {
            print('❌ Erreur enrichissement utilisateur: $e');
            print('📍 Stack trace: $stackTrace');
            // En cas d'erreur, ajouter avec les données de base uniquement
            enrichedUsers.add(UserSearchResult(
              id: user['id'] as String,
              displayName: user['display_name'] as String? ?? user['email'] as String? ?? 'Utilisateur',
              email: user['email'] as String?,
              isProfilePrivate: true, // Par défaut, traiter comme privé en cas d'erreur
            ));
          }
        }

        // Vérifier les demandes d'amitié existantes
        await _checkPendingRequests(enrichedUsers.map((u) => u.id).toList());

        if (!mounted) return;
        setState(() {
          _userResults = enrichedUsers;
          _loading = false;
        });
      } else {
        final data = await supabase
            .from('reading_groups')
            .select('*, group_members(count)')
            .or('name.ilike.$pattern,description.ilike.$pattern')
            .eq('is_private', false)
            .limit(20);

        if (!mounted) return;
        setState(() {
          _groupResults = (data as List).map((json) {
            final memberCount = json['group_members'] != null
                ? (json['group_members'] as List).length
                : 0;
            return ReadingGroup.fromJson({
              ...Map<String, dynamic>.from(json as Map),
              'member_count': memberCount,
            });
          }).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la recherche')),
      );
    }
  }

  Future<void> _checkPendingRequests(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final client = Supabase.instance.client;

      // Construire la requête OR pour tous les utilisateurs
      final orConditions = userIds.map((userId) =>
        'and(requester_id.eq.${currentUser.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${currentUser.id})'
      ).join(',');

      final existing = await client
          .from('friends')
          .select('addressee_id, requester_id, status')
          .or(orConditions);

      final pendingMap = <String, bool>{};
      for (final friendship in (existing as List)) {
        final addresseeId = friendship['addressee_id'] as String;
        final requesterId = friendship['requester_id'] as String;
        final status = friendship['status'] as String?;

        final friendId = addresseeId == currentUser.id ? requesterId : addresseeId;
        pendingMap[friendId] = status == 'pending' || status == 'accepted';
      }

      setState(() => _pendingRequests = pendingMap);
    } catch (e) {
      print('Erreur _checkPendingRequests: $e');
    }
  }

  Future<void> _addFriend(UserSearchResult user) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetId = user.id;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour ajouter un ami')),
      );
      return;
    }
    if (targetId == currentUser.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur invalide')),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;

      final existing = await client
          .from('friends')
          .select('id, status')
          .or(
            'and(requester_id.eq.${currentUser.id},addressee_id.eq.$targetId),and(requester_id.eq.$targetId,addressee_id.eq.${currentUser.id})',
          )
          .limit(1);

      if ((existing as List).isNotEmpty) {
        final status = (existing.first as Map)['status'] as String? ?? 'en attente';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Relation déjà $status')),
        );
        return;
      }

      await client.from('friends').insert({
        'requester_id': currentUser.id,
        'addressee_id': targetId,
        'status': 'pending',
      });

      setState(() => _pendingRequests[targetId] = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation envoyée')),
      );
    } catch (e) {
      print('Erreur _addFriend: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter cet ami')),
      );
    }
  }

  Future<void> _cancelFriendRequest(UserSearchResult user) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      await Supabase.instance.client
          .from('friends')
          .delete()
          .eq('requester_id', currentUser.id)
          .eq('addressee_id', user.id)
          .eq('status', 'pending');

      setState(() => _pendingRequests.remove(user.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande annulée')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'annuler la demande')),
      );
    }
  }

  void _switchTab(int index) {
    setState(() {
      _selectedTab = index;
      _userResults = [];
      _groupResults = [];
    });
    if (_controller.text.trim().length >= 2) {
      _search(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              const BackHeader(
                title: 'Rechercher',
                titleColor: Color(0xFF1A1A1A),
              ),
              const SizedBox(height: AppSpace.m),

              // Tab toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchTab(0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          child: Center(
                            child: Text(
                              'Amis',
                              style: TextStyle(
                                color: _selectedTab == 0
                                    ? AppColors.white
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchTab(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          child: Center(
                            child: Text(
                              'Groupes',
                              style: TextStyle(
                                color: _selectedTab == 1
                                    ? AppColors.white
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.m),

              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _selectedTab == 0
                      ? 'Nom ou email'
                      : 'Nom du groupe',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _search,
              ),

              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),

              Expanded(
                child: _selectedTab == 0
                    ? _buildUserResults()
                    : _buildGroupResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty && !_loading) {
      return Center(
        child: Text(
          'Tape au moins 2 caractères pour chercher',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      itemCount: _userResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xs),
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final isPending = _pendingRequests[user.id] ?? false;

        return _buildSimpleUserItem(user, isPending);
      },
    );
  }

  Widget _buildSimpleUserItem(UserSearchResult user, bool isPending) {
    return GestureDetector(
      onTap: () => _showUserDetailsModal(user, isPending),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpace.m),

            // Nom + indicateur privé
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.isProfilePrivate) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.lock, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Profil privé',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Flèche pour indiquer qu'on peut cliquer
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsModal(UserSearchResult user, bool isPending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de fermeture
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Carte détaillée
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.l),
                child: UserSearchCard(
                  user: user,
                  isRequestPending: isPending,
                  onAddFriend: () {
                    _addFriend(user);
                    Navigator.pop(context);
                  },
                  onCancelRequest: () {
                    _cancelFriendRequest(user);
                    Navigator.pop(context);
                  },
                  onTap: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupResults() {
    if (_groupResults.isEmpty && !_loading) {
      return Center(
        child: Text(
          'Tape au moins 2 caractères pour chercher',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      itemCount: _groupResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) {
        final group = _groupResults[index];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailPage(groupId: group.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpace.m),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: group.coverUrl != null
                      ? NetworkImage(group.coverUrl!)
                      : null,
                  child: group.coverUrl == null
                      ? const Icon(Icons.group, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: AppSpace.m),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (group.description != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          group.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '${group.memberCount ?? 0} membre${(group.memberCount ?? 0) > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}

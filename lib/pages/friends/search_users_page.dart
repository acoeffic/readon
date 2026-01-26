import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../models/reading_group.dart';
import '../groups/group_detail_page.dart';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _userResults = [];
  List<ReadingGroup> _groupResults = [];
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
        final data = await supabase
            .from('profiles')
            .select('id, display_name, email')
            .or('display_name.ilike.$pattern,email.ilike.$pattern')
            .limit(20);

        if (!mounted) return;
        setState(() {
          _userResults = (data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
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

  Future<void> _addFriend(Map<String, dynamic> user) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetId = user['id'] as String?;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour ajouter un ami')),
      );
      return;
    }
    if (targetId == null || targetId == currentUser.id) {
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation envoyée')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter cet ami')),
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
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final name = (user['display_name'] ?? user['email']) as String? ?? '';
        final email = user['email'] as String? ?? '';

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
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
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

              TextButton(
                onPressed: () => _addFriend(user),
                child: const Text('Ajouter', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      },
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
                  backgroundColor: AppColors.primary.withOpacity(0.1),
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

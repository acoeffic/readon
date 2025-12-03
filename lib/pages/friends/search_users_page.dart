import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String term) async {
    final query = term.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final supabase = Supabase.instance.client;
    final pattern = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

    try {
      final data = await supabase
          .from('profiles')
          .select('id, display_name, email')
          .or('display_name.ilike.$pattern,email.ilike.$pattern')
          .limit(20);

      if (!mounted) return;

      setState(() {
        _results = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
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
        const SnackBar(content: Text('Impossible d’ajouter cet ami')),
      );
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
              const BackHeader(title: 'Rechercher des amis'),
              const SizedBox(height: AppSpace.m),

              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Nom ou email',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _search,
              ),

              const SizedBox(height: AppSpace.m),
              if (_loading) const LinearProgressIndicator(),

              Expanded(
                child: _results.isEmpty && !_loading
                    ? Center(
                        child: Text(
                          'Tape au moins 2 caractères pour chercher',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
                        itemBuilder: (context, index) {
                          final user = _results[index];
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

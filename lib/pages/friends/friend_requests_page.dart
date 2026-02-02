import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
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
      // Récupérer les demandes pending où je suis le destinataire
      final friendsData = await supabase
          .from('friends')
          .select('id, requester_id')
          .eq('addressee_id', user.id)
          .eq('status', 'pending');

      if ((friendsData as List).isEmpty) {
        if (!mounted) return;
        setState(() {
          _requests = [];
          _loading = false;
          _error = null;
        });
        return;
      }

      // Récupérer les profils des demandeurs
      final requesterIds = friendsData.map((f) => f['requester_id'] as String).toList();
      final profiles = await supabase
          .from('profiles')
          .select('id, display_name, email')
          .inFilter('id', requesterIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in (profiles as List)) {
        profileMap[p['id'] as String] = Map<String, dynamic>.from(p);
      }

      final list = friendsData.map((f) {
        final requesterId = f['requester_id'] as String;
        final profile = profileMap[requesterId];
        return {
          'request_id': f['id'],
          'display_name': profile?['display_name'] ?? 'Utilisateur',
          'email': profile?['email'] ?? '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Erreur _loadRequests: $e');
      if (!mounted) return;
      setState(() {
        _error = "Impossible de récupérer les demandes";
        _loading = false;
      });
    }
  }

  Future<void> _respond(String requestId, bool accept) async {
    final supabase = Supabase.instance.client;

    setState(() => _processing.add(requestId));

    try {
      if (accept) {
        await supabase
            .from('friends')
            .update({'status': 'accepted'})
            .eq('id', requestId);
      } else {
        await supabase
            .from('friends')
            .delete()
            .eq('id', requestId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Ami ajouté' : 'Demande refusée')),
      );

      await _loadRequests();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible')),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Demandes d’amis'),
              const SizedBox(height: AppSpace.m),

              if (_loading) const LinearProgressIndicator(),

              if (_error != null && !_loading)
                Expanded(
                  child: Center(
                    child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),

              if (!_loading && _requests.isEmpty && _error == null)
                Expanded(
                  child: Center(
                    child: Text('Aucune demande', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),

              if (!_loading && _requests.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      final name = req['display_name'] as String? ?? 'Utilisateur';
                      final email = req['email'] as String? ?? '';
                      final rid = req['request_id']?.toString() ?? '';
                      final processing = _processing.contains(rid);

                      return Container(
                        padding: const EdgeInsets.all(AppSpace.m),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: Theme.of(context).dividerColor),
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
                                  Text(email, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),

                            if (processing)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: AppColors.primary),
                                onPressed: () => _respond(rid, true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: AppColors.error),
                                onPressed: () => _respond(rid, false),
                              ),
                            ],
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
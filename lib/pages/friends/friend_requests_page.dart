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
      final data = await supabase.rpc('get_friend_requests', params: {
        'uid': user.id,
      });

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
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
      await supabase.rpc('respond_friend_request', params: {
        'rid': requestId,
        'accept': accept,
      });

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
      backgroundColor: AppColors.bgLight,
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
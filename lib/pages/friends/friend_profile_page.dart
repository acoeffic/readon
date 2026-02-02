import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/badges_service.dart';
import '../../services/streak_service.dart';
import '../../widgets/badges_grid.dart';

class FriendProfilePage extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialAvatar;

  const FriendProfilePage({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatar,
  });

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final supabase = Supabase.instance.client;
  final badgesService = BadgesService();
  final streakService = StreakService();

  bool _loading = true;
  String _userName = '';
  String? _avatarUrl;
  String _memberSince = '';
  int _booksFinished = 0;
  int _totalPages = 0;
  int _totalHours = 0;
  int _currentStreak = 0;
  List<Map<String, dynamic>> _recentSessions = [];
  List<UserBadge> _badges = [];
  String? _friendshipStatus; // 'accepted', 'pending', null
  bool _isProfilePrivate = false;
  bool _canViewDetails = false; // true si public OU ami accepté

  @override
  void initState() {
    super.initState();
    _userName = widget.initialName ?? '';
    _avatarUrl = widget.initialAvatar;
    _loadAll();
  }

  Future<void> _loadAll() async {
    // IMPORTANT: Charger d'abord le profil pour avoir is_profile_private
    await _loadProfile();

    // Puis charger le statut d'amitié (qui dépend de is_profile_private)
    await _loadFriendshipStatus();

    // Charger les détails uniquement si autorisé
    if (_canViewDetails) {
      await Future.wait([
        _loadStats(),
        _loadStreak(),
        _loadRecentSessions(),
        _loadBadges(),
      ]);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('display_name, avatar_url, created_at, is_profile_private')
          .eq('id', widget.userId)
          .maybeSingle();

      if (profile != null && mounted) {
        final isPrivate = profile['is_profile_private'] as bool? ?? false;

        setState(() {
          _userName = profile['display_name'] as String? ?? widget.initialName ?? 'Utilisateur';
          _avatarUrl = profile['avatar_url'] as String? ?? widget.initialAvatar;
          _isProfilePrivate = isPrivate;
          if (profile['created_at'] != null) {
            _memberSince = _formatMemberSince(DateTime.parse(profile['created_at'] as String));
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadProfile: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await supabase.rpc(
        'get_friend_profile_stats',
        params: {'p_user_id': widget.userId},
      );

      if (response != null && mounted) {
        final stats = response is Map<String, dynamic>
            ? response
            : Map<String, dynamic>.from(response as Map);
        setState(() {
          _booksFinished = (stats['books_finished'] as num?)?.toInt() ?? 0;
          _totalPages = (stats['total_pages'] as num?)?.toInt() ?? 0;
          _totalHours = ((stats['total_minutes'] as num?)?.toDouble() ?? 0) ~/ 60;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadStats: $e');
    }
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await streakService.getStreakForUser(widget.userId);
      if (mounted) setState(() => _currentStreak = streak);
    } catch (e) {
      debugPrint('Erreur _loadStreak: $e');
    }
  }

  Future<void> _loadRecentSessions() async {
    try {
      final response = await supabase.rpc(
        'get_friend_recent_sessions',
        params: {'p_user_id': widget.userId},
      );

      if (response != null && mounted) {
        final sessions = (response as List)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        setState(() => _recentSessions = sessions);
      }
    } catch (e) {
      debugPrint('Erreur _loadRecentSessions: $e');
    }
  }

  Future<void> _loadBadges() async {
    try {
      final badges = await badgesService.getUserBadgesById(widget.userId);
      if (mounted) setState(() => _badges = badges);
    } catch (e) {
      debugPrint('Erreur _loadBadges: $e');
    }
  }

  Future<void> _loadFriendshipStatus() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final result = await supabase
          .from('friends')
          .select('status')
          .or('and(requester_id.eq.$currentUserId,addressee_id.eq.${widget.userId}),'
              'and(requester_id.eq.${widget.userId},addressee_id.eq.$currentUserId)')
          .limit(1);

      if (mounted) {
        String? status;
        if ((result as List).isNotEmpty) {
          status = result[0]['status'] as String?;
        }

        setState(() {
          _friendshipStatus = status;
          // On peut voir les détails si:
          // 1. Le profil est public (!_isProfilePrivate)
          // 2. OU si on est ami accepté (status == 'accepted')
          _canViewDetails = !_isProfilePrivate || status == 'accepted';
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadFriendshipStatus: $e');
    }
  }

  String _formatMemberSince(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays < 7) {
      return 'Membre depuis ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Membre depuis $weeks semaine${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Membre depuis $months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Membre depuis $years an${years > 1 ? 's' : ''}';
    }
  }

  String _formatDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return '';
    final start = DateTime.parse(startTime);
    final end = DateTime.parse(endTime);
    final minutes = end.difference(start).inMinutes;
    if (minutes >= 60) {
      return '${minutes ~/ 60}h ${minutes % 60}min';
    }
    return '${minutes}min';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    const months = ['jan', 'fev', 'mar', 'avr', 'mai', 'juin', 'juil', 'aout', 'sep', 'oct', 'nov', 'dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _addFriend() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await supabase.from('friends').insert({
        'requester_id': currentUserId,
        'addressee_id': widget.userId,
        'status': 'pending',
      });

      setState(() => _friendshipStatus = 'pending');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande envoyee')),
        );
      }
    } catch (e) {
      debugPrint('Erreur _addFriend: $e');
    }
  }

  Future<void> _cancelFriendRequest() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await supabase
          .from('friends')
          .delete()
          .eq('requester_id', currentUserId)
          .eq('addressee_id', widget.userId)
          .eq('status', 'pending');

      setState(() => _friendshipStatus = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande annulée')),
        );
      }
    } catch (e) {
      debugPrint('Erreur _cancelFriendRequest: $e');
    }
  }

  Future<void> _removeFriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer cet ami ?'),
        content: Text('Voulez-vous retirer $_userName de vos amis ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUserId = supabase.auth.currentUser!.id;
      await supabase.rpc('remove_friend', params: {
        'uid': currentUserId,
        'fid': widget.userId,
      });

      setState(() => _friendshipStatus = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ami retire')),
        );
      }
    } catch (e) {
      debugPrint('Erreur _removeFriend: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_userName, style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _loadAll();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- HEADER ---
                    _buildHeader(),
                    const SizedBox(height: AppSpace.xl),

                    // Si profil privé et pas ami, afficher un message
                    if (_isProfilePrivate && !_canViewDetails) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpace.l),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: AppSpace.m),
                            Text(
                              'Profil privé',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpace.s),
                            Text(
                              'Ce profil est privé. Ajoutez $_userName en ami pour voir ses statistiques.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.l),
                    ],

                    // Afficher les détails uniquement si autorisé
                    if (_canViewDetails) ...[
                      // --- STATS ---
                      _buildStats(),
                      const SizedBox(height: AppSpace.l),

                      // --- RECENT ACTIVITY ---
                      _buildRecentActivity(),
                      const SizedBox(height: AppSpace.l),

                      // --- BADGES ---
                      if (_badges.isNotEmpty) ...[
                        _buildBadges(),
                        const SizedBox(height: AppSpace.l),
                      ],
                    ],

                    // --- FRIEND ACTION ---
                    _buildFriendAction(),
                    const SizedBox(height: AppSpace.l),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.accentDark
                : AppColors.accentLight,
            image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(_avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _avatarUrl == null || _avatarUrl!.isEmpty
              ? Center(
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpace.m),
        Text(
          _userName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (_memberSince.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            _memberSince,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.l, horizontal: AppSpace.m),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.book, '$_booksFinished', 'Livres'),
          _buildStatItem(Icons.menu_book, '$_totalPages', 'Pages'),
          _buildStatItem(Icons.schedule, '${_totalHours}h', 'Lecture'),
          _buildStatItem(Icons.local_fire_department, '$_currentStreak', 'Streak'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: AppSpace.xs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activite recente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.m),
          if (_recentSessions.isEmpty)
            Text(
              'Aucune activite recente',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...List.generate(_recentSessions.length, (index) {
              final session = _recentSessions[index];
              final pagesRead = ((session['end_page'] as num?) ?? 0) - ((session['start_page'] as num?) ?? 0);
              final duration = _formatDuration(
                session['start_time'] as String?,
                session['end_time'] as String?,
              );
              final date = _formatDate(session['end_time'] as String?);
              final bookTitle = session['book_title'] as String? ?? 'Livre inconnu';

              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpace.s),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      child: const Icon(Icons.auto_stories, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${pagesRead > 0 ? '$pagesRead pages' : ''}${pagesRead > 0 && duration.isNotEmpty ? ' · ' : ''}$duration',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: BadgesGrid(
        badges: _badges,
        title: 'Ses badges',
      ),
    );
  }

  Widget _buildFriendAction() {
    if (_friendshipStatus == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _removeFriend,
          icon: const Icon(Icons.person_remove),
          label: const Text('Retirer des amis'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.l),
            ),
          ),
        ),
      );
    } else if (_friendshipStatus == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelFriendRequest,
          icon: const Icon(Icons.close),
          label: const Text('Annuler la demande'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.l),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _addFriend,
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter en ami'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.l),
            ),
          ),
        ),
      );
    }
  }
}

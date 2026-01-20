import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';
import 'group_members_page.dart';
import 'package:intl/intl.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupsService _groupsService = GroupsService();

  ReadingGroup? _group;
  List<GroupActivity> _activities = [];
  bool _isLoading = true;
  bool _isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
    _loadActivities();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    try {
      final group = await _groupsService.getGroup(widget.groupId);
      setState(() {
        _group = group;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoadingActivities = true);
    try {
      final activities = await _groupsService.getGroupActivities(
        groupId: widget.groupId,
      );
      setState(() {
        _activities = activities;
        _isLoadingActivities = false;
      });
    } catch (e) {
      setState(() => _isLoadingActivities = false);
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Quitter le groupe ?'),
        content: const Text('Voulez-vous vraiment quitter ce groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Quitter',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupsService.leaveGroup(widget.groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez quitté le groupe'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _navigateToMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersPage(
          groupId: widget.groupId,
          isAdmin: _group?.isAdmin ?? false,
        ),
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    if (_group == null) return;

    final newVisibility = !_group!.isPrivate;
    final visibilityText = newVisibility ? 'privé' : 'public';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text('Rendre le groupe $visibilityText ?'),
        content: Text(
          newVisibility
              ? 'Le groupe sera uniquement accessible sur invitation. Les membres actuels restent dans le groupe.'
              : 'Le groupe sera visible par tous les utilisateurs dans la section "Découvrir".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Rendre $visibilityText'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupsService.updateGroup(
        groupId: widget.groupId,
        isPrivate: newVisibility,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Groupe maintenant $visibilityText'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload group data
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: const Center(child: Text('Groupe introuvable')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App bar with cover image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: _group!.coverUrl != null
                  ? Image.network(
                      _group!.coverUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.primary.withOpacity(0.3),
                      child: const Icon(
                        Icons.group,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
            ),
            actions: [
              if (_group!.isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'members') {
                      _navigateToMembers();
                    } else if (value == 'visibility') {
                      _toggleVisibility();
                    } else if (value == 'leave') {
                      _leaveGroup();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'members',
                      child: Row(
                        children: [
                          Icon(Icons.people),
                          SizedBox(width: 8),
                          Text('Gérer les membres'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'visibility',
                      child: Row(
                        children: [
                          Icon(_group!.isPrivate ? Icons.public : Icons.lock),
                          const SizedBox(width: 8),
                          Text(_group!.isPrivate ? 'Rendre public' : 'Rendre privé'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app, color: AppColors.error),
                          SizedBox(width: 8),
                          Text(
                            'Quitter le groupe',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: _leaveGroup,
                ),
            ],
          ),

          // Group info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _group!.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_group!.isPrivate)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock, size: 14, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                'Privé',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_group!.isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_group!.description != null) ...[
                    const SizedBox(height: AppSpace.m),
                    Text(
                      _group!.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.l),

                  // Stats row
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.people,
                        label: 'Membres',
                        value: '${_group!.memberCount ?? 0}',
                        onTap: _navigateToMembers,
                      ),
                      const SizedBox(width: AppSpace.m),
                      _StatCard(
                        icon: Icons.auto_stories,
                        label: 'Activités',
                        value: '${_activities.length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Activities section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activités du groupe',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadActivities,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Activities list
          _isLoadingActivities
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.xl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              : _activities.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: AppSpace.m),
                              Text(
                                'Aucune activité',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Les activités des membres apparaîtront ici',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final activity = _activities[index];
                            return _ActivityCard(activity: activity);
                          },
                          childCount: _activities.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.m),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final GroupActivity activity;

  const _ActivityCard({required this.activity});

  String _getActivityDescription() {
    switch (activity.activityType) {
      case 'reading_session':
        final pages = activity.payload['pages_read'] ?? 0;
        final bookTitle = activity.payload['book_title'] ?? 'un livre';
        return 'a lu $pages pages de "$bookTitle"';
      case 'book_finished':
        final bookTitle = activity.payload['book_title'] ?? 'un livre';
        return 'a terminé "$bookTitle" 🎉';
      case 'joined':
        return 'a rejoint le groupe';
      case 'comment':
        return activity.payload['content'] ?? 'a laissé un commentaire';
      case 'book_recommendation':
        final bookTitle = activity.payload['book_title'] ?? 'un livre';
        return 'recommande "$bookTitle"';
      default:
        return 'activité inconnue';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: activity.userAvatar != null
                  ? NetworkImage(activity.userAvatar!)
                  : null,
              child: activity.userAvatar == null
                  ? Text(
                      activity.displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: activity.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' ${_getActivityDescription()}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(activity.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

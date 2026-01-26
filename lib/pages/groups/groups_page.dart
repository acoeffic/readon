import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GroupsService _groupsService = GroupsService();

  List<ReadingGroup> _myGroups = [];
  List<ReadingGroup> _publicGroups = [];
  bool _isLoadingMyGroups = true;
  bool _isLoadingPublic = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMyGroups(),
      _loadPublicGroups(),
    ]);
  }

  Future<void> _loadMyGroups() async {
    setState(() => _isLoadingMyGroups = true);
    try {
      final groups = await _groupsService.getUserGroups();
      setState(() {
        _myGroups = groups;
        _isLoadingMyGroups = false;
      });
    } catch (e) {
      setState(() => _isLoadingMyGroups = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _loadPublicGroups() async {
    setState(() => _isLoadingPublic = true);
    try {
      final groups = await _groupsService.getPublicGroups();
      setState(() {
        _publicGroups = groups;
        _isLoadingPublic = false;
      });
    } catch (e) {
      setState(() => _isLoadingPublic = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }


  void _navigateToCreateGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
    );

    if (result == true) {
      _loadMyGroups();
    }
  }

  void _navigateToGroupDetail(ReadingGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailPage(groupId: group.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Club de lecture',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          tabs: [
            Tab(
              text: 'Mes groupes',
              icon: _myGroups.isEmpty
                  ? null
                  : Badge(
                      label: Text('${_myGroups.length}'),
                      child: const Icon(Icons.group),
                    ),
            ),
            Tab(
              text: 'Découvrir',
              icon: const Icon(Icons.public),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyGroupsTab(),
          _buildPublicGroupsTab(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateGroup,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Créer un Club',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    if (_isLoadingMyGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSpace.m),
            Text(
              'Aucun groupe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.s),
            const Text(
              'Créez ou rejoignez un groupe de lecture',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyGroups,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpace.m),
        itemCount: _myGroups.length,
        itemBuilder: (context, index) {
          final group = _myGroups[index];
          return _GroupCard(
            group: group,
            onTap: () => _navigateToGroupDetail(group),
          );
        },
      ),
    );
  }

  Widget _buildPublicGroupsTab() {
    if (_isLoadingPublic) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_publicGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSpace.m),
            Text(
              'Aucun groupe public',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.s),
            const Text(
              'Soyez le premier à créer un groupe public !',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublicGroups,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpace.m),
        itemCount: _publicGroups.length,
        itemBuilder: (context, index) {
          final group = _publicGroups[index];
          return _GroupCard(
            group: group,
            onTap: () => _navigateToGroupDetail(group),
            showCreator: true,
          );
        },
      ),
    );
  }

}

class _GroupCard extends StatelessWidget {
  final ReadingGroup group;
  final VoidCallback onTap;
  final bool showCreator;

  const _GroupCard({
    required this.group,
    required this.onTap,
    this.showCreator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            children: [
              // Group avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: group.coverUrl != null
                    ? NetworkImage(group.coverUrl!)
                    : null,
                child: group.coverUrl == null
                    ? const Icon(Icons.group, color: AppColors.primary, size: 30)
                    : null,
              ),
              const SizedBox(width: AppSpace.m),
              // Group info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isPrivate)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 12, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Privé',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (group.isAdmin)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (group.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount ?? 0} membre${(group.memberCount ?? 0) > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (showCreator && group.creatorName != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'par ${group.creatorName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

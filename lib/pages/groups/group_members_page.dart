import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';

class GroupMembersPage extends StatefulWidget {
  final String groupId;
  final bool isAdmin;

  const GroupMembersPage({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final GroupsService _groupsService = GroupsService();
  final supabase = Supabase.instance.client;

  List<GroupMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _groupsService.getGroupMembers(widget.groupId);
      setState(() {
        _members = members;
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

  Future<void> _inviteFriend() async {
    // Get current user's friends
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Fetch friends using RPC
      final friendsData = await supabase
          .rpc('get_friends', params: {'uid': userId});

      final friends = (friendsData as List).map((f) => {
        'id': f['id'] as String,
        'name': f['display_name'] as String? ?? f['email'] as String,
      }).toList();

      // Filter out friends who are already members
      final memberIds = _members.map((m) => m.userId).toSet();
      final availableFriends = friends.where((f) => !memberIds.contains(f['id'])).toList();

      if (availableFriends.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tous vos amis sont déjà membres du groupe'),
            ),
          );
        }
        return;
      }

      // Show friend selection dialog
      if (!mounted) return;
      final selectedFriend = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          title: const Text('Inviter un ami'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableFriends.length,
              itemBuilder: (context, index) {
                final friend = availableFriends[index];
                return ListTile(
                  title: Text(friend['name'] as String),
                  onTap: () => Navigator.of(ctx).pop(friend),
                );
              },
            ),
          ),
        ),
      );

      if (selectedFriend == null) return;

      // Send invitation
      await _groupsService.inviteUser(
        groupId: widget.groupId,
        inviteeId: selectedFriend['id'] as String,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Invitation envoyée à ${selectedFriend['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _updateMemberRole(GroupMember member, String newRole) async {
    try {
      await _groupsService.updateMemberRole(
        groupId: widget.groupId,
        userId: member.userId,
        role: newRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rôle de ${member.displayName} mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Retirer du groupe ?'),
        content: Text('Voulez-vous retirer ${member.displayName} du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Retirer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupsService.removeMember(
        groupId: widget.groupId,
        userId: member.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.displayName} a été retiré du groupe'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showMemberOptions(GroupMember member) {
    if (!widget.isAdmin) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text(member.isAdmin ? 'Rétrograder en membre' : 'Promouvoir admin'),
              onTap: () {
                Navigator.pop(ctx);
                _updateMemberRole(
                  member,
                  member.isAdmin ? 'member' : 'admin',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.error),
              title: const Text(
                'Retirer du groupe',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _removeMember(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Membres (${_members.length})',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  if (widget.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: _inviteFriend,
                      tooltip: 'Inviter un ami',
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: AppSpace.m),
                              const Text(
                                'Aucun membre',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMembers,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.l,
                            ),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              final isCurrentUser =
                                  member.userId == supabase.auth.currentUser?.id;

                              return Card(
                                margin: const EdgeInsets.only(bottom: AppSpace.m),
                                color: Theme.of(context).cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.m),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    backgroundImage: member.userAvatar != null
                                        ? NetworkImage(member.userAvatar!)
                                        : null,
                                    child: member.userAvatar == null
                                        ? Text(
                                            member.displayName
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          member.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentUser)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Vous',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    member.isAdmin ? 'Administrateur' : 'Membre',
                                    style: TextStyle(
                                      color: member.isAdmin
                                          ? AppColors.primary
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: widget.isAdmin && !isCurrentUser
                                      ? IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          onPressed: () => _showMemberOptions(member),
                                        )
                                      : member.isAdmin
                                          ? const Icon(
                                              Icons.admin_panel_settings,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

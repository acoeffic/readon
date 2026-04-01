import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';

const _kSageGreen = Color(0xFF6B988D);

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
  List<GroupJoinRequest> _joinRequests = [];
  bool _isLoading = true;
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    if (widget.isAdmin) _loadJoinRequests();
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

  Future<void> _loadJoinRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final requests = await _groupsService.getJoinRequests(widget.groupId);
      if (mounted) {
        setState(() {
          _joinRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _respondToJoinRequest(GroupJoinRequest request, bool accept) async {
    final l = AppLocalizations.of(context);
    try {
      await _groupsService.respondToJoinRequest(
        requestId: request.id,
        accept: accept,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? l.joinRequestAccepted(request.displayName)
                : l.joinRequestRejected(request.displayName)),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
        _loadJoinRequests();
        if (accept) _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _inviteFriend() async {
    final l = AppLocalizations.of(context);
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
            SnackBar(
              content: Text(l.allFriendsInGroup),
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
          title: Text(l.inviteFriend),
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
            content: Text(AppLocalizations.of(context).invitationSent(selectedFriend['name'] as String)),
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
            content: Text(AppLocalizations.of(context).roleUpdated(member.displayName)),
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
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(l.removeFromGroupTitle),
        content: Text(l.removeFromGroupMessage(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.removeButton,
              style: const TextStyle(color: AppColors.error),
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
            content: Text(AppLocalizations.of(context).memberRemoved(member.displayName)),
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

    final l = AppLocalizations.of(context);
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
              title: Text(member.isAdmin ? l.demoteToMember : l.promoteAdmin),
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
              title: Text(
                l.removeFromGroup,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _removeMember(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text(l.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinRequestsSection() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.pendingJoinRequests(_joinRequests.length),
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kSageGreen,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          ..._joinRequests.map((request) => Card(
                margin: const EdgeInsets.only(bottom: AppSpace.s),
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: BorderSide(
                    color: _kSageGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _kSageGreen.withValues(alpha: 0.15),
                        backgroundImage: request.userAvatar != null
                            ? NetworkImage(request.userAvatar!)
                            : null,
                        child: request.userAvatar == null
                            ? Text(
                                request.displayName.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: _kSageGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.displayName,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (request.message != null && request.message!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  request.message!,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: l.accept,
                        onPressed: () => _respondToJoinRequest(request, true),
                      ),
                      IconButton(
                        icon: Icon(Icons.cancel, color: Colors.red.shade400),
                        tooltip: l.reject,
                        onPressed: () => _respondToJoinRequest(request, false),
                      ),
                    ],
                  ),
                ),
              )),
          const Divider(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                        l.membersCount(_members.length),
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
                      tooltip: l.inviteFriend,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            // Pending join requests section (admin only)
            if (widget.isAdmin && !_isLoadingRequests && _joinRequests.isNotEmpty)
              _buildJoinRequestsSection(),

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
                              Text(
                                l.noMembers,
                                style: const TextStyle(
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
                                    backgroundColor: AppColors.primary.withValues(alpha:0.1),
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
                                            color: Colors.blue.withValues(alpha:0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            l.youTag,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    member.isAdmin ? l.administrator : l.memberRole,
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

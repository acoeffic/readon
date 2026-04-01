import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_group.dart';
import '../models/feature_flags.dart';
import 'subscription_service.dart';

class GroupsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Vérifie que l'utilisateur gratuit n'a pas atteint la limite de clubs
  Future<void> _enforceGroupLimit() async {
    final premium = await _subscriptionService.isPremium();
    if (premium) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final result = await _supabase
        .from('group_members')
        .select('id')
        .eq('user_id', userId);

    if ((result as List).length >= FeatureFlags.maxFreeGroups) {
      throw Exception(
        'Limite de ${FeatureFlags.maxFreeGroups} clubs atteinte. '
        'Passe à Premium pour en rejoindre plus !',
      );
    }
  }

  // =====================================================
  // GROUP MANAGEMENT
  // =====================================================

  /// Create a new reading group
  Future<ReadingGroup> createGroup({
    required String name,
    String? description,
    String? coverUrl,
    bool isPrivate = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _enforceGroupLimit();

    final response = await _supabase
        .from('reading_groups')
        .insert({
          'name': name,
          'description': description,
          'cover_url': coverUrl,
          'is_private': isPrivate,
          'creator_id': userId,
        })
        .select()
        .single();

    return ReadingGroup.fromJson(response);
  }

  /// Get user's groups (groups they are a member of)
  Future<List<ReadingGroup>> getUserGroups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .rpc('get_user_groups', params: {'p_user_id': userId});

    return (response as List)
        .map((json) => ReadingGroup.fromJson(json))
        .toList();
  }

  /// Get public groups
  Future<List<ReadingGroup>> getPublicGroups({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase.rpc('get_public_groups', params: {
      'p_limit': limit,
      'p_offset': offset,
    });

    return (response as List)
        .map((json) => ReadingGroup.fromJson(json))
        .toList();
  }

  /// Get group details
  Future<ReadingGroup> getGroup(String groupId) async {
    final response = await _supabase
        .from('reading_groups')
        .select('''
          *,
          group_members(count)
        ''')
        .eq('id', groupId)
        .single();

    // Get user's role if they're a member
    final userId = _supabase.auth.currentUser?.id;
    String? userRole;

    if (userId != null) {
      final memberResponse = await _supabase
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      userRole = memberResponse?['role'] as String?;
    }

    final memberCount = response['group_members'] != null
        ? (response['group_members'] as List).length
        : 0;

    // Check if user has a pending join request (only if not a member)
    bool hasPendingRequest = false;
    if (userId != null && userRole == null) {
      try {
        hasPendingRequest = await hasPendingJoinRequest(groupId);
      } catch (_) {
        // RPC may not be deployed yet — treat as no pending request
        hasPendingRequest = false;
      }
    }

    return ReadingGroup.fromJson({
      ...response,
      'member_count': memberCount,
      'user_role': userRole,
      'has_pending_request': hasPendingRequest,
    });
  }

  /// Update group details
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool clearDescription = false,
    String? coverUrl,
    bool? isPrivate,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (clearDescription) {
      updates['description'] = null;
    } else if (description != null) {
      updates['description'] = description;
    }
    if (coverUrl != null) updates['cover_url'] = coverUrl;
    if (isPrivate != null) updates['is_private'] = isPrivate;

    await _supabase
        .from('reading_groups')
        .update(updates)
        .eq('id', groupId);
  }

  /// Delete group
  Future<void> deleteGroup(String groupId) async {
    await _supabase
        .from('reading_groups')
        .delete()
        .eq('id', groupId);
  }

  /// Leave group
  Future<void> leaveGroup(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Check membership before attempting to leave
    final member = await _supabase
        .from('group_members')
        .select('id')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (member == null) {
      throw Exception('Not a member of this group');
    }

    await _supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  // =====================================================
  // MEMBER MANAGEMENT
  // =====================================================

  /// Get group members with profile info
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final membersResponse = await _supabase
        .from('group_members')
        .select('*')
        .eq('group_id', groupId)
        .order('joined_at', ascending: false);

    final members = membersResponse as List;
    if (members.isEmpty) return [];

    final userIds = members.map((m) => m['user_id'] as String).toList();
    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, display_name, email, avatar_url')
        .inFilter('id', userIds);

    final profilesMap = {
      for (final p in profilesResponse as List)
        p['id'] as String: p as Map<String, dynamic>
    };

    return members.map((json) {
      final profile = profilesMap[json['user_id'] as String];
      return GroupMember.fromJson({
        ...json,
        'user_name': profile?['display_name'],
        'user_email': profile?['email'],
        'user_avatar': profile?['avatar_url'],
      });
    }).toList();
  }

  /// Update member role
  Future<void> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    await _supabase
        .from('group_members')
        .update({'role': role})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Remove member from group
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  // =====================================================
  // INVITATION MANAGEMENT
  // =====================================================

  /// Send group invitation
  Future<void> inviteUser({
    required String groupId,
    required String inviteeId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Check if user is already a member
    final existingMember = await _supabase
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', inviteeId)
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('User is already a member of this group');
    }

    // Check if invitation already exists
    final existingInvitation = await _supabase
        .from('group_invitations')
        .select()
        .eq('group_id', groupId)
        .eq('invitee_id', inviteeId)
        .eq('status', 'pending')
        .maybeSingle();

    if (existingInvitation != null) {
      throw Exception('Invitation already sent');
    }

    await _supabase
        .from('group_invitations')
        .insert({
          'group_id': groupId,
          'inviter_id': userId,
          'invitee_id': inviteeId,
          'status': 'pending',
        });
  }

  /// Get user's group invitations
  Future<List<GroupInvitation>> getUserInvitations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .rpc('get_group_invitations', params: {'p_user_id': userId});

    return (response as List)
        .map((json) => GroupInvitation.fromJson(json))
        .toList();
  }

  /// Respond to group invitation
  Future<void> respondToInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    if (accept) {
      await _enforceGroupLimit();
    }

    await _supabase.rpc('respond_to_group_invitation', params: {
      'p_invitation_id': invitationId,
      'p_accept': accept,
    });
  }

  // =====================================================
  // JOIN REQUESTS
  // =====================================================

  /// Request to join a group
  Future<void> requestToJoin({
    required String groupId,
    String? message,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from('group_join_requests').insert({
      'group_id': groupId,
      'user_id': userId,
      'message': message,
      'status': 'pending',
    });
  }

  /// Cancel own join request
  Future<void> cancelJoinRequest(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('group_join_requests')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('status', 'pending');
  }

  /// Check if user has a pending join request
  Future<bool> hasPendingJoinRequest(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .rpc('has_pending_join_request', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
    });

    return response as bool? ?? false;
  }

  /// Get pending join requests for a group (admin only)
  Future<List<GroupJoinRequest>> getJoinRequests(String groupId) async {
    final response = await _supabase
        .rpc('get_group_join_requests', params: {'p_group_id': groupId});

    return (response as List)
        .map((json) => GroupJoinRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Respond to a join request (admin only)
  Future<void> respondToJoinRequest({
    required String requestId,
    required bool accept,
  }) async {
    await _supabase.rpc('respond_to_join_request', params: {
      'p_request_id': requestId,
      'p_accept': accept,
    });
  }

  /// Watch pending join requests count for a group (real-time)
  Stream<int> watchPendingJoinRequestsCount(String groupId) {
    return _supabase
        .from('group_join_requests')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .map((data) => data
            .where((r) => r['status'] == 'pending')
            .length);
  }

  // =====================================================
  // GROUP ACTIVITIES
  // =====================================================

  /// Get group activities with user info
  Future<List<GroupActivity>> getGroupActivities({
    required String groupId,
    int limit = 20,
    int offset = 0,
  }) async {
    final activitiesResponse = await _supabase
        .from('group_activities')
        .select('*')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final activities = activitiesResponse as List;
    if (activities.isEmpty) return [];

    final userIds = activities.map((a) => a['user_id'] as String).toSet().toList();
    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', userIds);

    final profilesMap = {
      for (final p in profilesResponse as List)
        p['id'] as String: p as Map<String, dynamic>
    };

    return activities.map((json) {
      final profile = profilesMap[json['user_id'] as String];
      return GroupActivity.fromJson({
        ...json,
        'user_name': profile?['display_name'],
        'user_avatar': profile?['avatar_url'],
      });
    }).toList();
  }

  /// Create group activity
  Future<void> createGroupActivity({
    required String groupId,
    required String activityType,
    required Map<String, dynamic> payload,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('group_activities')
        .insert({
          'group_id': groupId,
          'user_id': userId,
          'activity_type': activityType,
          'payload': payload,
        });
  }

  // =====================================================
  // REAL-TIME STREAMS
  // =====================================================

  /// Watch group activities in real-time
  Stream<List<GroupActivity>> watchGroupActivities(String groupId) {
    return _supabase
        .from('group_activities')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => GroupActivity.fromJson(json)).toList());
  }

  /// Watch group members in real-time
  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    return _supabase
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('joined_at', ascending: false)
        .map((data) => data.map((json) => GroupMember.fromJson(json)).toList());
  }

  /// Watch user's invitations
  Stream<int> watchPendingInvitationsCount() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    return _supabase
        .from('group_invitations')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .where((invitation) =>
                invitation['invitee_id'] == userId &&
                invitation['status'] == 'pending')
            .length);
  }
}

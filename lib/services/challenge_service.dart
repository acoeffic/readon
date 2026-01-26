import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_challenge.dart';

class ChallengeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new challenge (admin only via RLS)
  Future<GroupChallenge> createChallenge({
    required String groupId,
    required String type,
    required String title,
    String? description,
    int? targetBookId,
    required int targetValue,
    int? targetDays,
    required DateTime endsAt,
    DateTime? startsAt,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('group_challenges')
        .insert({
          'group_id': groupId,
          'creator_id': userId,
          'type': type,
          'title': title,
          'description': description,
          'target_book_id': targetBookId,
          'target_value': targetValue,
          'target_days': targetDays,
          'starts_at': (startsAt ?? DateTime.now()).toIso8601String(),
          'ends_at': endsAt.toIso8601String(),
        })
        .select()
        .single();

    return GroupChallenge.fromJson(response);
  }

  /// Get all challenges for a group with user participation info
  Future<List<GroupChallenge>> getChallenges(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('group_challenges')
        .select('''
          *,
          books:target_book_id(title, cover_url),
          challenge_participants(count),
          my_participation:challenge_participants!inner(progress, completed)
        ''')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    // Fetch separately because !inner filters out non-participants
    final participationResponse = await _supabase
        .from('challenge_participants')
        .select('challenge_id, progress, completed')
        .eq('user_id', userId);

    final participationMap = <String, Map<String, dynamic>>{};
    for (final p in participationResponse) {
      participationMap[p['challenge_id'] as String] = p;
    }

    return (response as List).map((json) {
      final book = json['books'] as Map<String, dynamic>?;
      final participantCount = json['challenge_participants'] is List
          ? (json['challenge_participants'] as List).length
          : 0;
      final myParticipation = participationMap[json['id'] as String];

      return GroupChallenge.fromJson({
        ...json,
        'target_book_title': book?['title'],
        'target_book_cover': book?['cover_url'],
        'participant_count': participantCount,
        'user_progress': myParticipation?['progress'],
        'user_completed': myParticipation?['completed'] ?? false,
        'user_joined': myParticipation != null,
      });
    }).toList();
  }

  /// Get active challenges for a group
  Future<List<GroupChallenge>> getActiveChallenges(String groupId) async {
    final all = await getChallenges(groupId);
    return all.where((c) => c.isActive).toList();
  }

  /// Join a challenge
  Future<void> joinChallenge(String challengeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('challenge_participants')
        .insert({
          'challenge_id': challengeId,
          'user_id': userId,
        });
  }

  /// Leave a challenge
  Future<void> leaveChallenge(String challengeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('challenge_participants')
        .delete()
        .eq('challenge_id', challengeId)
        .eq('user_id', userId);
  }

  /// Get participants for a challenge
  Future<List<ChallengeParticipant>> getParticipants(String challengeId) async {
    final response = await _supabase
        .from('challenge_participants')
        .select('''
          *,
          profiles:user_id(display_name, avatar_url)
        ''')
        .eq('challenge_id', challengeId)
        .order('progress', ascending: false);

    return (response as List).map((json) {
      final profile = json['profiles'] as Map<String, dynamic>?;
      return ChallengeParticipant.fromJson({
        ...json,
        'user_name': profile?['display_name'],
        'user_avatar': profile?['avatar_url'],
      });
    }).toList();
  }

  /// Update progress for current user in a challenge
  Future<void> updateProgress({
    required String challengeId,
    required int progress,
    bool completed = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final updates = <String, dynamic>{
      'progress': progress,
      'completed': completed,
    };
    if (completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await _supabase
        .from('challenge_participants')
        .update(updates)
        .eq('challenge_id', challengeId)
        .eq('user_id', userId);
  }

  /// Delete a challenge (admin only via RLS)
  Future<void> deleteChallenge(String challengeId) async {
    await _supabase
        .from('group_challenges')
        .delete()
        .eq('id', challengeId);
  }

  /// Get active challenges the user participates in (for progress tracking)
  Future<List<Map<String, dynamic>>> getUserActiveChallenges() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('challenge_participants')
        .select('''
          challenge_id,
          progress,
          group_challenges!inner(
            id, type, target_value, target_days, target_book_id, ends_at
          )
        ''')
        .eq('user_id', userId)
        .eq('completed', false);

    // Filter to only active challenges
    final now = DateTime.now();
    return (response as List).where((p) {
      final challenge = p['group_challenges'] as Map<String, dynamic>;
      final endsAt = DateTime.parse(challenge['ends_at'] as String);
      return endsAt.isAfter(now);
    }).map((p) {
      final challenge = p['group_challenges'] as Map<String, dynamic>;
      return {
        'challenge_id': p['challenge_id'],
        'current_progress': p['progress'],
        'type': challenge['type'],
        'target_value': challenge['target_value'],
        'target_days': challenge['target_days'],
        'target_book_id': challenge['target_book_id'],
      };
    }).toList();
  }

  /// Update challenge progress after a reading session
  Future<void> updateProgressAfterSession({
    required String bookId,
    required int pagesRead,
    required int durationMinutes,
  }) async {
    final activeChallenges = await getUserActiveChallenges();

    for (final challenge in activeChallenges) {
      final type = challenge['type'] as String;
      final challengeId = challenge['challenge_id'] as String;
      final currentProgress = challenge['current_progress'] as int;
      final targetValue = challenge['target_value'] as int;

      switch (type) {
        case 'read_book':
          final targetBookId = challenge['target_book_id'];
          if (targetBookId != null && targetBookId.toString() == bookId) {
            // Mark as completed when reading this specific book
            await updateProgress(
              challengeId: challengeId,
              progress: currentProgress + pagesRead,
              completed: true,
            );
          }
          break;

        case 'read_pages':
          final newProgress = currentProgress + pagesRead;
          await updateProgress(
            challengeId: challengeId,
            progress: newProgress,
            completed: newProgress >= targetValue,
          );
          break;

        case 'read_daily':
          if (durationMinutes >= targetValue) {
            final targetDays = challenge['target_days'] as int? ?? 7;
            final newProgress = currentProgress + 1;
            await updateProgress(
              challengeId: challengeId,
              progress: newProgress,
              completed: newProgress >= targetDays,
            );
          }
          break;
      }
    }
  }
}

// lib/services/comments_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Comment {
  final String id;
  final int activityId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? authorEmail;
  final String? authorName;
  final String? authorAvatar;

  Comment({
    required this.id,
    required this.activityId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.authorEmail,
    this.authorName,
    this.authorAvatar,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      activityId: json['activity_id'] as int,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      authorEmail: json['author_email'] as String?,
      authorName: json['author_name'] as String?,
      authorAvatar: json['author_avatar'] as String?,
    );
  }

  String get displayName => authorName ?? authorEmail ?? 'Utilisateur';
}

class CommentsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupérer les commentaires d'une activité
  Future<List<Comment>> getComments(int activityId) async {
    try {
      final response = await _supabase
          .rpc('get_activity_comments', params: {'p_activity_id': activityId});

      if (response == null) return [];

      return (response as List)
          .map((item) => Comment.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('Erreur getComments: $e');
      return [];
    }
  }

  /// Ajouter un commentaire
  Future<Comment?> addComment({
    required int activityId,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      // Valider la longueur
      if (content.trim().isEmpty || content.length > 500) {
        throw Exception('Le commentaire doit contenir entre 1 et 500 caractères');
      }

      final response = await _supabase
          .from('comments')
          .insert({
            'activity_id': activityId,
            'author_id': userId,
            'content': content.trim(),
          })
          .select()
          .single();

      // Récupérer avec les infos user
      final enriched = await _supabase
          .from('comments_with_user')
          .select()
          .eq('id', response['id'])
          .single();

      return Comment.fromJson(enriched);
    } catch (e) {
      debugPrint('Erreur addComment: $e');
      return null;
    }
  }

  /// Modifier un commentaire
  Future<bool> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      if (content.trim().isEmpty || content.length > 500) {
        throw Exception('Le commentaire doit contenir entre 1 et 500 caractères');
      }

      await _supabase
          .from('comments')
          .update({'content': content.trim()})
          .eq('id', commentId);

      return true;
    } catch (e) {
      debugPrint('Erreur updateComment: $e');
      return false;
    }
  }

  /// Supprimer un commentaire
  Future<bool> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId);

      return true;
    } catch (e) {
      debugPrint('Erreur deleteComment: $e');
      return false;
    }
  }

  /// Stream temps réel des commentaires
  Stream<List<Comment>> watchComments(int activityId) {
    return _supabase
        .from('comments_with_user')
        .stream(primaryKey: ['id'])
        .eq('activity_id', activityId)
        .order('created_at', ascending: true)
        .map((data) => data.map((item) => Comment.fromJson(item)).toList());
  }
}
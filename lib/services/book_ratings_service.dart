// lib/services/book_ratings_service.dart
//
// CRUD sur la table book_ratings (une note par lecture / user_book).
// RLS : l'utilisateur ne voit que ses notes + les notes publiques de ses amis.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book_rating.dart';

class BookRatingsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Note de l'utilisateur courant pour ce livre (lecture la plus récente).
  Future<BookRating?> getMyRating(int bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('book_ratings')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return BookRating.fromJson(response);
    } catch (e) {
      debugPrint('Erreur getMyRating: $e');
      return null;
    }
  }

  /// Crée ou met à jour la note de la lecture courante (unique par user_book).
  Future<BookRating> upsertRating({
    required int bookId,
    required double rating,
    Map<String, dynamic>? criteria,
    List<String>? emotionTags,
    String? reviewText,
    bool? wouldRecommend,
    bool? wouldReread,
    bool? isPublic,
    bool abandoned = false,
    int? abandonedAtPercent,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      // Retrouver la lecture (user_book) concernée
      final userBook = await _supabase
          .from('user_books')
          .select('id')
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();
      if (userBook == null) {
        throw Exception('Livre absent de la bibliothèque');
      }
      final userBookId = userBook['id'] as int;

      final existing = await _supabase
          .from('book_ratings')
          .select('id')
          .eq('user_book_id', userBookId)
          .maybeSingle();

      // L'appelant envoie l'état complet : les nulls sont volontaires
      // (avis effacé, critère désélectionné, "non répondu").
      final payload = <String, dynamic>{
        'rating': rating,
        'abandoned': abandoned,
        'criteria': criteria,
        'emotion_tags': emotionTags ?? const <String>[],
        'review_text': reviewText,
        'would_recommend': wouldRecommend,
        'would_reread': wouldReread,
        if (isPublic != null) 'is_public': isPublic,
        'abandoned_at_percent': abandonedAtPercent,
      };

      final Map<String, dynamic> row;
      if (existing != null) {
        row = await _supabase
            .from('book_ratings')
            .update(payload)
            .eq('id', existing['id'] as int)
            .select()
            .single();
      } else {
        row = await _supabase
            .from('book_ratings')
            .insert({
              'user_id': userId,
              'book_id': bookId,
              'user_book_id': userBookId,
              ...payload,
            })
            .select()
            .single();
      }
      return BookRating.fromJson(row);
    } catch (e) {
      debugPrint('Erreur upsertRating: $e');
      rethrow;
    }
  }

  /// Supprime la note de l'utilisateur courant pour cette lecture.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _supabase.from('book_ratings').delete().eq('id', ratingId);
    } catch (e) {
      debugPrint('Erreur deleteRating: $e');
      rethrow;
    }
  }
}

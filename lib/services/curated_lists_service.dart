import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CuratedListsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---- Save/Unsave a list ----

  Future<void> saveList(int listId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase.from('user_saved_curated_lists').insert({
        'user_id': userId,
        'list_id': listId,
      });
    } catch (e) {
      debugPrint('Erreur saveList: $e');
      rethrow;
    }
  }

  Future<void> unsaveList(int listId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase
          .from('user_saved_curated_lists')
          .delete()
          .eq('user_id', userId)
          .eq('list_id', listId);
    } catch (e) {
      debugPrint('Erreur unsaveList: $e');
      rethrow;
    }
  }

  Future<bool> isListSaved(int listId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('user_saved_curated_lists')
          .select('id')
          .eq('user_id', userId)
          .eq('list_id', listId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Erreur isListSaved: $e');
      return false;
    }
  }

  Future<Set<int>> getSavedListIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('user_saved_curated_lists')
          .select('list_id')
          .eq('user_id', userId);

      return (response as List)
          .map((row) => row['list_id'] as int)
          .toSet();
    } catch (e) {
      debugPrint('Erreur getSavedListIds: $e');
      return {};
    }
  }

  // ---- Reader counts ----

  Future<Map<int, int>> getReaderCounts(List<int> listIds) async {
    try {
      if (listIds.isEmpty) return {};

      final response = await _supabase
          .from('user_saved_curated_lists')
          .select('list_id')
          .inFilter('list_id', listIds);

      final counts = <int, int>{};
      for (final row in response as List) {
        final listId = row['list_id'] as int;
        counts[listId] = (counts[listId] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('Erreur getReaderCounts: $e');
      return {};
    }
  }

  // ---- Book read tracking ----

  Future<void> markBookRead(int listId, String isbn) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase.from('user_curated_book_reads').insert({
        'user_id': userId,
        'list_id': listId,
        'book_isbn': isbn,
      });
    } catch (e) {
      debugPrint('Erreur markBookRead: $e');
      rethrow;
    }
  }

  Future<void> unmarkBookRead(int listId, String isbn) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await _supabase
          .from('user_curated_book_reads')
          .delete()
          .eq('user_id', userId)
          .eq('list_id', listId)
          .eq('book_isbn', isbn);
    } catch (e) {
      debugPrint('Erreur unmarkBookRead: $e');
      rethrow;
    }
  }

  Future<Set<String>> getReadBookIsbns(int listId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('user_curated_book_reads')
          .select('book_isbn')
          .eq('user_id', userId)
          .eq('list_id', listId);

      return (response as List)
          .map((row) => row['book_isbn'] as String)
          .toSet();
    } catch (e) {
      debugPrint('Erreur getReadBookIsbns: $e');
      return {};
    }
  }

  Future<Map<int, int>> getReadCountsPerList(Set<int> listIds) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};
      if (listIds.isEmpty) return {};

      final response = await _supabase
          .from('user_curated_book_reads')
          .select('list_id')
          .eq('user_id', userId)
          .inFilter('list_id', listIds.toList());

      final counts = <int, int>{};
      for (final row in response as List) {
        final listId = row['list_id'] as int;
        counts[listId] = (counts[listId] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('Erreur getReadCountsPerList: $e');
      return {};
    }
  }
}

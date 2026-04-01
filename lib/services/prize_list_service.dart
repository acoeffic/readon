import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prize_list.dart';

class PrizeListService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches all active prize lists, ordered by year desc.
  Future<List<PrizeList>> fetchPrizeLists() async {
    try {
      final response = await _supabase
          .from('prize_lists')
          .select('*')
          .eq('is_active', true)
          .order('year', ascending: false);

      return (response as List)
          .map((e) => PrizeList.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erreur fetchPrizeLists: $e');
      return [];
    }
  }

  /// Fetches books for a specific prize list, ordered by position.
  Future<List<PrizeListBook>> fetchBooksForList(String listId) async {
    try {
      final response = await _supabase
          .from('prize_list_books')
          .select('*')
          .eq('list_id', listId)
          .order('position');

      return (response as List)
          .map((e) => PrizeListBook.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erreur fetchBooksForList: $e');
      return [];
    }
  }

  /// Fetches distinct prize names for grouping.
  Future<List<String>> fetchDistinctPrizeNames() async {
    try {
      final response = await _supabase
          .from('prize_lists')
          .select('prize_name')
          .eq('is_active', true);

      final names = <String>{};
      for (final row in response as List) {
        names.add(row['prize_name'] as String);
      }
      return names.toList();
    } catch (e) {
      debugPrint('Erreur fetchDistinctPrizeNames: $e');
      return [];
    }
  }

  /// Fetches thematic lists only.
  Future<List<PrizeList>> fetchThematicLists() async {
    try {
      final response = await _supabase
          .from('prize_lists')
          .select('*')
          .eq('is_active', true)
          .eq('list_type', 'thematic');

      return (response as List)
          .map((e) => PrizeList.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erreur fetchThematicLists: $e');
      return [];
    }
  }

  /// Fetches recent prize lists (latest year per prize) for the carousel.
  Future<List<PrizeList>> fetchRecentPrizeLists({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('prize_lists')
          .select('*')
          .eq('is_active', true)
          .eq('list_type', 'prize_year')
          .order('year', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => PrizeList.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erreur fetchRecentPrizeLists: $e');
      return [];
    }
  }
}

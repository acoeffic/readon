import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/feature_flags.dart';
import '../models/user_custom_list.dart';
import 'subscription_service.dart';

class UserCustomListsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SubscriptionService _subscriptionService = SubscriptionService();

  // ---- List CRUD ----

  Future<UserCustomList> createList({
    required String title,
    required String iconName,
    required String gradientColor,
    bool isPublic = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      // Vérifier la limite pour les utilisateurs non-premium
      final premium = await _subscriptionService.isPremium();
      if (!premium) {
        final existing = await _supabase
            .from('user_custom_lists')
            .select('id')
            .eq('user_id', userId);
        if ((existing as List).length >= FeatureFlags.maxFreeCustomLists) {
          throw Exception(
            'Limite de ${FeatureFlags.maxFreeCustomLists} listes atteinte. '
            'Passe à Premium pour en créer plus !',
          );
        }
      }

      // Validation des entrées
      final cleanTitle = title.trim().replaceAll(RegExp(r'<[^>]*>'), '');
      if (cleanTitle.isEmpty || cleanTitle.length > 100) {
        throw Exception('Le titre doit contenir entre 1 et 100 caractères');
      }
      if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(iconName)) {
        throw Exception('Icône invalide');
      }
      if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(gradientColor)) {
        throw Exception('Couleur invalide');
      }

      final response = await _supabase.from('user_custom_lists').insert({
        'user_id': userId,
        'title': cleanTitle,
        'icon_name': iconName,
        'gradient_color': gradientColor,
        'is_public': isPublic,
      }).select().single();

      return UserCustomList.fromJson(response);
    } catch (e) {
      debugPrint('Erreur createList: $e');
      rethrow;
    }
  }

  Future<void> updateList(
    int listId, {
    String? title,
    String? iconName,
    String? gradientColor,
    bool? isPublic,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) {
        final cleanTitle = title.trim().replaceAll(RegExp(r'<[^>]*>'), '');
        if (cleanTitle.isEmpty || cleanTitle.length > 100) {
          throw Exception('Le titre doit contenir entre 1 et 100 caractères');
        }
        updates['title'] = cleanTitle;
      }
      if (iconName != null) {
        if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(iconName)) {
          throw Exception('Icône invalide');
        }
        updates['icon_name'] = iconName;
      }
      if (gradientColor != null) {
        if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(gradientColor)) {
          throw Exception('Couleur invalide');
        }
        updates['gradient_color'] = gradientColor;
      }
      if (isPublic != null) {
        updates['is_public'] = isPublic;
      }

      await _supabase
          .from('user_custom_lists')
          .update(updates)
          .eq('id', listId);
    } catch (e) {
      debugPrint('Erreur updateList: $e');
      rethrow;
    }
  }

  Future<void> deleteList(int listId) async {
    try {
      await _supabase.from('user_custom_lists').delete().eq('id', listId);
    } catch (e) {
      debugPrint('Erreur deleteList: $e');
      rethrow;
    }
  }

  Future<List<UserCustomList>> getUserLists() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('user_custom_lists')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserCustomList.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getUserLists: $e');
      return [];
    }
  }

  Future<UserCustomList> getListWithBooks(int listId) async {
    try {
      final response = await _supabase
          .from('user_custom_lists')
          .select('*, user_custom_list_books(*, books(*))')
          .eq('id', listId)
          .single();

      final bookEntries = response['user_custom_list_books'] as List? ?? [];

      // Trier par position puis par added_at
      bookEntries.sort((a, b) {
        final posA = a['position'] as int? ?? 0;
        final posB = b['position'] as int? ?? 0;
        if (posA != posB) return posA.compareTo(posB);
        final dateA = a['added_at'] as String? ?? '';
        final dateB = b['added_at'] as String? ?? '';
        return dateA.compareTo(dateB);
      });

      final books = bookEntries
          .where((entry) => entry['books'] != null)
          .map((entry) => Book.fromJson(entry['books'] as Map<String, dynamic>))
          .toList();

      return UserCustomList.fromJson(response, books: books);
    } catch (e) {
      debugPrint('Erreur getListWithBooks: $e');
      rethrow;
    }
  }

  // ---- Book management ----

  Future<void> addBookToList(int listId, int bookId) async {
    try {
      // Déterminer la position (après le dernier livre)
      final existing = await _supabase
          .from('user_custom_list_books')
          .select('position')
          .eq('list_id', listId)
          .order('position', ascending: false)
          .limit(1);

      final nextPosition =
          existing.isNotEmpty ? (existing[0]['position'] as int) + 1 : 0;

      await _supabase.from('user_custom_list_books').insert({
        'list_id': listId,
        'book_id': bookId,
        'position': nextPosition,
      });
    } catch (e) {
      debugPrint('Erreur addBookToList: $e');
      rethrow;
    }
  }

  Future<void> removeBookFromList(int listId, int bookId) async {
    try {
      await _supabase
          .from('user_custom_list_books')
          .delete()
          .eq('list_id', listId)
          .eq('book_id', bookId);
    } catch (e) {
      debugPrint('Erreur removeBookFromList: $e');
      rethrow;
    }
  }

  Future<Set<int>> getListIdsContainingBook(int bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('user_custom_list_books')
          .select('list_id, user_custom_lists!inner(user_id)')
          .eq('book_id', bookId)
          .eq('user_custom_lists.user_id', userId);

      return (response as List)
          .map((row) => row['list_id'] as int)
          .toSet();
    } catch (e) {
      debugPrint('Erreur getListIdsContainingBook: $e');
      return {};
    }
  }

  Future<Map<int, int>> getBookCountsPerList(List<int> listIds) async {
    try {
      if (listIds.isEmpty) return {};

      final response = await _supabase
          .from('user_custom_list_books')
          .select('list_id')
          .inFilter('list_id', listIds);

      final counts = <int, int>{};
      for (final row in response as List) {
        final listId = row['list_id'] as int;
        counts[listId] = (counts[listId] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('Erreur getBookCountsPerList: $e');
      return {};
    }
  }
}

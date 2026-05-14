import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubCover {
  final String id;
  final String url;
  final String? name;
  final String? category;
  final int sortOrder;

  const ClubCover({
    required this.id,
    required this.url,
    this.name,
    this.category,
    required this.sortOrder,
  });

  factory ClubCover.fromJson(Map<String, dynamic> json) {
    return ClubCover(
      id: json['id'] as String,
      url: json['url'] as String,
      name: json['name'] as String?,
      category: json['category'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClubCoversService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache mémoire simple — la lib ne change pas souvent, on évite de re-fetch
  // à chaque ouverture du picker.
  static List<ClubCover>? _cache;

  Future<List<ClubCover>> getAvailable({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final res = await _supabase
          .from('club_cover_library')
          .select('id, url, name, category, sort_order')
          .eq('is_active', true)
          .order('sort_order')
          .order('created_at');
      final list = (res as List)
          .map((e) => ClubCover.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      debugPrint('🖼  club_cover_library fetched: ${list.length} covers');
      _cache = list;
      return list;
    } catch (e, stack) {
      debugPrint('❌ ClubCoversService.getAvailable error: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  void invalidateCache() {
    _cache = null;
  }
}

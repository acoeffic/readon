// services/curated_lists_repository.dart
// Catalogue des listes curatées, chargé depuis Supabase (tables
// `curated_lists` + `curated_list_books`). Ajouter/modifier une liste se fait
// par un simple INSERT/UPDATE en base, sans rebuild de l'app.
//
// Chaîne de fallback : réseau → cache Hive → données embarquées
// (kCuratedLists, snapshot du catalogue au moment du build).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/curated_lists_data.dart';
import '../models/curated_list.dart';

class CuratedListsRepository {
  static const String _boxName = 'curated_lists_cache';
  static const String _dataKey = 'lists_json';

  static List<CuratedList>? _lists;
  static bool _fetchedFromNetwork = false;
  static Future<List<CuratedList>>? _inflight;

  /// Listes actuellement connues. Jamais vide : tant que ni le réseau ni le
  /// cache n'ont répondu, retourne les listes embarquées dans le binaire.
  static List<CuratedList> get lists => _lists ?? kCuratedLists;

  /// Charge le catalogue depuis Supabase (une seule fois par session, les
  /// appels suivants sont instantanés). En cas d'échec réseau, retombe sur le
  /// cache Hive puis sur les données embarquées. Ne throw jamais.
  static Future<List<CuratedList>> ensureLoaded() {
    if (_fetchedFromNetwork) return Future.value(lists);
    return _inflight ??= _load().whenComplete(() => _inflight = null);
  }

  static Future<List<CuratedList>> _load() async {
    // 1️⃣ Réseau
    try {
      final rows = await Supabase.instance.client
          .from('curated_lists')
          .select('id, title, subtitle, description, icon, gradient_colors, '
              'curated_list_books(isbn, title, author, position)')
          .order('sort_order', ascending: true)
          .order('position',
              referencedTable: 'curated_list_books', ascending: true);
      final parsed = _parseRows(rows);
      if (parsed.isNotEmpty) {
        _lists = parsed;
        _fetchedFromNetwork = true;
        _saveToCache(rows);
        return parsed;
      }
    } catch (e) {
      debugPrint('CuratedListsRepository: fetch réseau échoué ($e)');
    }

    // 2️⃣ Cache Hive (offline)
    if (_lists == null) {
      final cached = await _loadFromCache();
      if (cached != null && cached.isNotEmpty) _lists = cached;
    }

    // 3️⃣ Fallback embarqué (via le getter)
    return lists;
  }

  static List<CuratedList> _parseRows(dynamic rows) {
    return (rows as List<dynamic>)
        .map((r) => CuratedList.fromJson(Map<String, dynamic>.from(r as Map)))
        .where((l) => l.books.isNotEmpty)
        .toList();
  }

  static Future<void> _saveToCache(dynamic rows) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_dataKey, jsonEncode(rows));
    } catch (e) {
      debugPrint('CuratedListsRepository: écriture cache échouée ($e)');
    }
  }

  static Future<List<CuratedList>?> _loadFromCache() async {
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get(_dataKey) as String?;
      if (raw == null) return null;
      return _parseRows(jsonDecode(raw));
    } catch (e) {
      debugPrint('CuratedListsRepository: lecture cache échouée ($e)');
      return null;
    }
  }
}

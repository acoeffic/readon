// lib/services/reco_events_service.dart
//
// Mesure du funnel des suggestions du feed : affichée → ouverte → ajoutée.
// Écrit dans public.ai_reco_events (migration 20261028000000). Toujours
// best-effort : une erreur de tracking ne doit jamais gêner l'utilisateur.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/book_suggestion.dart';
import 'google_books_service.dart';

class RecoEventsService {
  RecoEventsService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
  };

  /// Minuscules, sans accents ni ponctuation, espaces simples.
  static String normalize(String? s) {
    final lower = (s ?? '').toLowerCase();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_accents[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// Clé stable titre|auteur : identique que le livre ait déjà un id
  /// (en base) ou non (résultat Google Books), pour relier shown → added.
  static String bookKey(Book book) {
    final key = 't:${normalize(book.title)}|${normalize(book.author)}';
    return key.length > 200 ? key.substring(0, 200) : key;
  }

  /// Toutes les clés sous lesquelles un livre peut être reconnu (id en base,
  /// google_id, titre+auteur, titre seul). Sert au dédoublonnage et à
  /// l'exclusion des livres déjà dans la bibliothèque.
  static Set<String> matchKeys(Book book) {
    final keys = <String>{};
    if (book.id > 0) keys.add('i:${book.id}');
    final g = book.googleId;
    if (g != null && g.isNotEmpty) keys.add('g:$g');
    final t = normalize(book.title);
    if (t.isNotEmpty) {
      keys.add('t:$t|${normalize(book.author)}');
      keys.add('T:$t');
    }
    return keys;
  }

  /// Enregistre l'affichage des suggestions (une ligne par livre et par jour).
  static Future<void> trackShown(List<BookSuggestion> suggestions) async {
    if (suggestions.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < suggestions.length; i++) {
        rows.add(_row(userId, 'shown', suggestions[i], i));
      }
      await _upsert(rows);
    } catch (e) {
      debugPrint('RecoEventsService.trackShown: $e');
    }
  }

  /// [event] : 'opened' | 'added' | 'amazon'.
  static Future<void> track(
    String event,
    BookSuggestion suggestion, {
    int? rank,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _upsert([_row(userId, event, suggestion, rank)]);
    } catch (e) {
      debugPrint('RecoEventsService.track($event): $e');
    }
  }

  /// Vrai si [g] correspond bien au livre cité "[title]" de [author] :
  /// titre contenu (dans un sens ou l'autre) ou ≥ 60 % de mots en commun,
  /// ET nom de famille de l'auteur retrouvé quand Google Books en donne un.
  /// Sert à détecter les titres inventés par le modèle dans le chat.
  static bool matchesPick(GoogleBook g, String title, String author) {
    final gt = normalize(g.title);
    final at = normalize(title);
    if (gt.isEmpty || at.isEmpty) return false;
    var titleOk = gt.contains(at) || at.contains(gt);
    if (!titleOk) {
      final aTokens = at.split(' ').where((t) => t.length > 2).toList();
      if (aTokens.isEmpty) return false;
      final gTokens = gt.split(' ').toSet();
      final common = aTokens.where(gTokens.contains).length;
      titleOk = common / aTokens.length >= 0.6;
    }
    if (!titleOk) return false;
    final gAuthors = normalize(g.authorsString);
    final parts = normalize(author).split(' ');
    final surname = parts.isEmpty ? '' : parts.last;
    if (gAuthors.isEmpty || surname.length < 3) return true;
    return gAuthors.contains(surname);
  }

  /// Événement hors carrousel (ex. livre cité dans le chat Muse, source 'chat').
  static Future<void> trackRaw(
    String event,
    String source, {
    required String title,
    String? author,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final key = 't:${normalize(title)}|${normalize(author)}';
      String clip(String? v, int max) =>
          v == null ? '' : (v.length > max ? v.substring(0, max) : v);
      await _upsert([
        {
          'user_id': userId,
          'event': event,
          'source': source,
          'book_key': key.length > 200 ? key.substring(0, 200) : key,
          'title': clip(title, 300),
          'author': clip(author, 300),
        }
      ]);
    } catch (e) {
      debugPrint('RecoEventsService.trackRaw($event): $e');
    }
  }

  static Map<String, dynamic> _row(
    String userId,
    String event,
    BookSuggestion s,
    int? rank,
  ) {
    String clip(String? v, int max) =>
        v == null ? '' : (v.length > max ? v.substring(0, max) : v);
    return {
      'user_id': userId,
      'event': event,
      'source': s.type.name,
      'book_key': bookKey(s.book),
      'title': clip(s.book.title, 300),
      'author': clip(s.book.author, 300),
      if (rank != null) 'rank': rank,
    };
  }

  static Future<void> _upsert(List<Map<String, dynamic>> rows) {
    return _supabase.from('ai_reco_events').upsert(
          rows,
          onConflict: 'user_id,event,book_key,event_day',
          ignoreDuplicates: true,
        );
  }
}

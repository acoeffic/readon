// lib/services/last_page_cache.dart
//
// Mémoire locale de la dernière page atteinte, par livre.
//
// Pourquoi ce cache existe : `getBookStats()` s'appuie sur `getBookSessions()`,
// qui renvoie une liste **vide** en cas d'erreur réseau. Résultat, hors ligne un
// livre lu jusqu'à la page 187 est indiscernable d'un livre jamais ouvert — et
// la session repartait silencieusement à la page 1, faussant la progression.
//
// Ce cache est écrit à chaque fois qu'on connaît la vérité (stats chargées,
// session terminée) et relu quand le serveur ne répond pas.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class LastPageCache {
  static String _key(String bookId) => 'last_page_$bookId';

  /// Dernière page connue pour ce livre, ou `null` si on n'a jamais rien su.
  static Future<int?> get(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(bookId));
    } catch (e) {
      debugPrint('LastPageCache.get: $e');
      return null;
    }
  }

  /// Mémorise la page atteinte. Ne recule jamais : une session antidatée
  /// saisie après coup ne doit pas faire redescendre la progression connue
  /// (même règle que `getBookStats`, qui prend le `end_page` maximum).
  static Future<void> set(String bookId, int page) async {
    if (page <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_key(bookId));
      if (current != null && current >= page) return;
      await prefs.setInt(_key(bookId), page);
    } catch (e) {
      debugPrint('LastPageCache.set: $e');
    }
  }

  /// Oubli d'un livre retiré de la bibliothèque.
  static Future<void> clear(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(bookId));
    } catch (e) {
      debugPrint('LastPageCache.clear: $e');
    }
  }
}

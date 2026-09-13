// lib/services/kindle_cookie_store.dart
//
// Cache des cookies Amazon pour le sync Kindle en arrière-plan.
//
// Les cookies vivent dans le store de la WebView (WKHTTPCookieStore sur iOS,
// android.webkit.CookieManager sur Android). webview_flutter ne sait pas les
// LIRE, et un isolate headless n'a de toute façon pas de WebView : on les
// copie donc en SharedPreferences depuis le premier plan (channel natif
// `fr.lexday.app/kindle_cookies`, voir AppDelegate.swift / MainActivity.kt)
// à la fin de chaque sync réussi, et l'arrière-plan les relit.
//
// Une copie peut devenir obsolète (rotation de session-token) : l'arrière-plan
// verra alors une redirection /ap/signin et ne fera rien ; le prochain passage
// au premier plan rafraîchit la copie. Purgée par `disconnect()`.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KindleCookieStore {
  static const MethodChannel _channel =
      MethodChannel('fr.lexday.app/kindle_cookies');
  static const String _prefsKey = 'kindle_cookie_header';
  static const String _prefsAtKey = 'kindle_cookie_header_at';

  /// Lit les cookies *.amazon.* dans le store de la WebView et les met en
  /// cache sous forme d'en-tête `Cookie`. Best-effort, silencieux.
  static Future<bool> refreshFromWebView() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getAmazonCookies');
      final header = _toHeader(raw);
      if (header == null || header.isEmpty) {
        debugPrint('KindleCookieStore: aucun cookie Amazon dans la WebView');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, header);
      await prefs.setString(_prefsAtKey, DateTime.now().toIso8601String());
      debugPrint(
          'KindleCookieStore: ${header.split(';').length} cookies mis en cache');
      return true;
    } on MissingPluginException {
      debugPrint('KindleCookieStore: channel natif absent (plateforme non gérée)');
      return false;
    } catch (e) {
      debugPrint('KindleCookieStore: refresh KO: $e');
      return false;
    }
  }

  /// En-tête `Cookie` en cache, ou `null`.
  static Future<String?> cachedHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getString(_prefsKey);
    return (h == null || h.isEmpty) ? null : h;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_prefsAtKey);
  }

  /// Le natif renvoie soit une liste de `{name, value}` (iOS), soit déjà une
  /// chaîne `name=value; …` (Android, CookieManager.getCookie).
  static String? _toHeader(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.trim();
    if (raw is List) {
      final parts = <String>[];
      for (final c in raw) {
        if (c is! Map) continue;
        final name = c['name']?.toString();
        final value = c['value']?.toString();
        if (name == null || name.isEmpty || value == null) continue;
        parts.add('$name=$value');
      }
      return parts.join('; ');
    }
    return null;
  }
}

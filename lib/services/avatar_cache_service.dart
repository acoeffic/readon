import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Service de cache local pour la photo de profil de l'utilisateur courant.
/// Sauvegarde l'image sur le disque et l'URL en SharedPreferences.
class AvatarCacheService {
  static const _keyAvatarUrl = 'cached_avatar_url';
  static const _keyAvatarPath = 'cached_avatar_path';

  AvatarCacheService._();
  static final instance = AvatarCacheService._();

  String? _cachedPath;
  String? _cachedUrl;
  bool _loaded = false;

  /// Charge les infos depuis SharedPreferences (appelé une seule fois).
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cachedUrl = prefs.getString(_keyAvatarUrl);
    _cachedPath = prefs.getString(_keyAvatarPath);
    _loaded = true;
  }

  /// Retourne le chemin local de l'avatar s'il existe sur le disque.
  Future<String?> getLocalPath() async {
    await _ensureLoaded();
    if (_cachedPath != null && File(_cachedPath!).existsSync()) {
      return _cachedPath;
    }
    return null;
  }

  /// Retourne l'URL distante cachée.
  Future<String?> getCachedUrl() async {
    await _ensureLoaded();
    return _cachedUrl;
  }

  /// Sauvegarde l'avatar depuis un fichier local (après upload).
  /// [sourceFile] est le fichier image original, [remoteUrl] l'URL Supabase.
  Future<void> saveFromFile(File sourceFile, String remoteUrl) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = sourceFile.path.split('.').last.toLowerCase();
      final destPath = '${dir.path}/avatar_profile.$ext';

      // Supprimer l'ancien fichier local si extension différente
      await _deleteOldFiles(dir.path, 'avatar_profile');

      await sourceFile.copy(destPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatarUrl, remoteUrl);
      await prefs.setString(_keyAvatarPath, destPath);

      _cachedUrl = remoteUrl;
      _cachedPath = destPath;
    } catch (e) {
      debugPrint('AvatarCacheService.saveFromFile error: $e');
    }
  }

  /// Télécharge et sauvegarde l'avatar depuis une URL distante.
  Future<void> saveFromUrl(String remoteUrl) async {
    try {
      await _ensureLoaded();
      // Si on a déjà cette URL en cache, pas besoin de re-télécharger
      if (_cachedUrl == remoteUrl && _cachedPath != null && File(_cachedPath!).existsSync()) {
        return;
      }

      final response = await http.get(Uri.parse(remoteUrl));
      if (response.statusCode != 200) return;

      final dir = await getApplicationDocumentsDirectory();
      // Deviner l'extension depuis le content-type ou l'URL
      final ext = _guessExtension(remoteUrl, response.headers['content-type']);
      final destPath = '${dir.path}/avatar_profile.$ext';

      await _deleteOldFiles(dir.path, 'avatar_profile');

      await File(destPath).writeAsBytes(response.bodyBytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatarUrl, remoteUrl);
      await prefs.setString(_keyAvatarPath, destPath);

      _cachedUrl = remoteUrl;
      _cachedPath = destPath;
    } catch (e) {
      debugPrint('AvatarCacheService.saveFromUrl error: $e');
    }
  }

  /// Supprime le cache local (logout / suppression de compte).
  Future<void> clear() async {
    try {
      if (_cachedPath != null) {
        final file = File(_cachedPath!);
        if (file.existsSync()) await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAvatarUrl);
      await prefs.remove(_keyAvatarPath);
      _cachedUrl = null;
      _cachedPath = null;
    } catch (e) {
      debugPrint('AvatarCacheService.clear error: $e');
    }
  }

  /// Supprime les anciens fichiers avatar_profile.* pour éviter les doublons.
  Future<void> _deleteOldFiles(String dirPath, String baseName) async {
    try {
      final dir = Directory(dirPath);
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains(baseName)) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  String _guessExtension(String url, String? contentType) {
    if (contentType != null) {
      if (contentType.contains('png')) return 'png';
      if (contentType.contains('webp')) return 'webp';
    }
    final urlExt = url.split('.').last.split('?').first.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp'].contains(urlExt)) return urlExt;
    return 'jpg';
  }
}

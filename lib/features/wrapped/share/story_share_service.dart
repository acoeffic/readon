import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../../utils/app_constants.dart';

/// Résultat d'une tentative de partage direct vers une Story.
enum StoryShareResult {
  /// L'app cible a été ouverte avec l'image préchargée en fond de Story.
  shared,

  /// L'app cible n'est pas installée (ou son scheme n'est pas déclaré).
  notInstalled,

  /// La plateforme ne supporte pas ce partage (channel absent, OS trop vieux).
  unsupported,

  /// Erreur inattendue côté natif.
  error,
}

/// Partage direct d'une image vers les Stories Instagram / Facebook.
///
/// Contrairement à un simple `instagram://app` (qui ouvre l'app SANS l'image),
/// ceci précharge l'image en fond du composer de Story via le pasteboard (iOS)
/// ou un Intent `ADD_TO_STORY` (Android) — le vrai partage « 1 tap » façon
/// Spotify Wrapped / Strava.
///
/// L'appelant DOIT gérer le retour : si ce n'est pas [StoryShareResult.shared],
/// retomber sur la feuille de partage native pour ne jamais laisser
/// l'utilisateur devant une app vide.
class StoryShareService {
  static const MethodChannel _channel =
      MethodChannel('fr.lexday.app/story_share');

  /// Partage [backgroundImage] (PNG, idéalement 1080×1920) en fond de Story
  /// Instagram.
  Future<StoryShareResult> shareToInstagramStory(Uint8List backgroundImage) =>
      _share('instagram', backgroundImage);

  /// Partage [backgroundImage] en fond de Story Facebook.
  Future<StoryShareResult> shareToFacebookStory(Uint8List backgroundImage) =>
      _share('facebook', backgroundImage);

  /// Partage la vidéo à [videoPath] (MP4, idéalement 1080×1920) en fond de
  /// Story Instagram. On passe le chemin du fichier (pas les octets) pour ne
  /// pas faire transiter plusieurs Mo par le channel.
  Future<StoryShareResult> shareVideoToInstagramStory(String videoPath) =>
      _shareVideo('instagram', videoPath);

  /// Partage la vidéo à [videoPath] en fond de Story Facebook.
  Future<StoryShareResult> shareVideoToFacebookStory(String videoPath) =>
      _shareVideo('facebook', videoPath);

  Future<StoryShareResult> _share(String target, Uint8List image) async {
    if (image.isEmpty) return StoryShareResult.error;
    return _invoke('shareToStory', {
      'target': target,
      'backgroundImage': image,
      'sourceApplication': kFacebookAppId,
    });
  }

  Future<StoryShareResult> _shareVideo(String target, String videoPath) async {
    if (videoPath.isEmpty) return StoryShareResult.error;
    return _invoke('shareVideoToStory', {
      'target': target,
      'videoPath': videoPath,
      'sourceApplication': kFacebookAppId,
    });
  }

  Future<StoryShareResult> _invoke(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final res = await _channel.invokeMethod<String>(method, args);
      switch (res) {
        case 'shared':
          return StoryShareResult.shared;
        case 'not_installed':
          return StoryShareResult.notInstalled;
        default:
          return StoryShareResult.error;
      }
    } on MissingPluginException {
      return StoryShareResult.unsupported;
    } on PlatformException {
      return StoryShareResult.error;
    }
  }
}

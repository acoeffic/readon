import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Share image format for the Yearly Wrapped card.
enum ShareFormat {
  /// 1080x1920 – Instagram/TikTok Story (9:16)
  story,

  /// 1080x1080 – Instagram Feed / Twitter Post (1:1)
  square;

  double get width => 1080;

  double get height => switch (this) {
        story => 1920,
        square => 1080,
      };

  double get aspectRatio => width / height;
}

/// Where the user wants to share their Wrapped image.
///
/// The [format] is determined automatically based on the destination.
/// Each destination maps to a URL scheme for deep linking.
enum ShareDestination {
  instagramStory,
  tiktok,
  instagramPost,
  twitter,
  linkedin,
  facebook,
  saveToGallery;

  String get label => switch (this) {
        instagramStory => 'Instagram Story',
        tiktok => 'TikTok',
        instagramPost => 'Instagram Post',
        twitter => 'X (Twitter)',
        linkedin => 'LinkedIn',
        facebook => 'Facebook',
        saveToGallery => "Sauvegarder l'image",
      };

  /// Brand icon for each destination.
  IconData get iconData => switch (this) {
        instagramStory => FontAwesomeIcons.instagram,
        tiktok => FontAwesomeIcons.tiktok,
        instagramPost => FontAwesomeIcons.instagram,
        twitter => FontAwesomeIcons.xTwitter,
        linkedin => FontAwesomeIcons.linkedin,
        facebook => FontAwesomeIcons.facebook,
        saveToGallery => Icons.save_alt,
      };

  /// Brand color for each destination.
  Color get brandColor => switch (this) {
        instagramStory => const Color(0xFFE4405F),
        tiktok => const Color(0xFF000000),
        instagramPost => const Color(0xFFE4405F),
        twitter => const Color(0xFF000000),
        linkedin => const Color(0xFF0A66C2),
        facebook => const Color(0xFF1877F2),
        saveToGallery => const Color(0xFF6B7280),
      };

  ShareFormat get format => switch (this) {
        instagramStory => ShareFormat.story,
        tiktok => ShareFormat.story,
        instagramPost => ShareFormat.square,
        twitter => ShareFormat.square,
        linkedin => ShareFormat.square,
        facebook => ShareFormat.square,
        saveToGallery => ShareFormat.story,
      };

  /// URL scheme used to open the target app via deep link.
  /// Returns `null` for destinations that don't open an external app.
  String? get urlScheme => switch (this) {
        instagramStory => 'instagram://app',
        tiktok => 'snssdk1233://',
        instagramPost => 'instagram://app',
        twitter => 'twitter://post',
        linkedin => 'linkedin://app',
        facebook => 'fb://publish',
        saveToGallery => null,
      };
}

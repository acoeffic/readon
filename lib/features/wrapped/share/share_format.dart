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

/// Where the user wants to share their image.
///
/// The [format] is determined automatically based on the destination.
/// Each destination maps to a URL scheme for deep linking.
enum ShareDestination {
  whatsapp,
  linkedin,
  twitter,
  tiktok,
  message,
  messenger,
  facebook,
  more;

  String get label => switch (this) {
        whatsapp => 'WhatsApp',
        linkedin => 'LinkedIn',
        twitter => 'X',
        tiktok => 'TikTok',
        message => 'Message',
        messenger => 'Messenger',
        facebook => 'Facebook',
        more => 'Plus',
      };

  /// Brand icon for each destination.
  IconData get iconData => switch (this) {
        whatsapp => FontAwesomeIcons.whatsapp,
        linkedin => FontAwesomeIcons.linkedin,
        twitter => FontAwesomeIcons.xTwitter,
        tiktok => FontAwesomeIcons.tiktok,
        message => Icons.message_rounded,
        messenger => FontAwesomeIcons.facebookMessenger,
        facebook => FontAwesomeIcons.facebook,
        more => Icons.ios_share,
      };

  /// Brand color for each destination.
  Color get brandColor => switch (this) {
        whatsapp => const Color(0xFF25D366),
        linkedin => const Color(0xFF0A66C2),
        twitter => const Color(0xFF000000),
        tiktok => const Color(0xFF000000),
        message => const Color(0xFF34C759),
        messenger => const Color(0xFF006AFF),
        facebook => const Color(0xFF1877F2),
        more => const Color(0xFF8E8E93),
      };

  ShareFormat get format => switch (this) {
        whatsapp => ShareFormat.story,
        linkedin => ShareFormat.square,
        twitter => ShareFormat.square,
        tiktok => ShareFormat.story,
        message => ShareFormat.story,
        messenger => ShareFormat.story,
        facebook => ShareFormat.square,
        more => ShareFormat.story,
      };

  /// URL scheme used to open the target app via deep link.
  /// Returns `null` for destinations that use the native share sheet directly.
  String? get urlScheme => switch (this) {
        whatsapp => null,
        linkedin => 'linkedin://app',
        twitter => 'twitter://post',
        tiktok => 'snssdk1233://',
        message => null,
        messenger => 'fb-messenger://',
        facebook => 'fb://publish',
        more => null,
      };
}

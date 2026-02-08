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
  saveToGallery;

  String get label => switch (this) {
        instagramStory => 'Instagram Story',
        tiktok => 'TikTok',
        instagramPost => 'Instagram Post',
        twitter => 'Twitter / X',
        linkedin => 'LinkedIn',
        saveToGallery => "Sauvegarder l'image",
      };

  String get icon => switch (this) {
        instagramStory => '\uD83D\uDCF8',
        tiktok => '\uD83C\uDFB5',
        instagramPost => '\uD83D\uDDBC\uFE0F',
        twitter => '\uD83D\uDC26',
        linkedin => '\uD83D\uDCBC',
        saveToGallery => '\uD83D\uDCBE',
      };

  ShareFormat get format => switch (this) {
        instagramStory => ShareFormat.story,
        tiktok => ShareFormat.story,
        instagramPost => ShareFormat.square,
        twitter => ShareFormat.square,
        linkedin => ShareFormat.square,
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
        saveToGallery => null,
      };
}

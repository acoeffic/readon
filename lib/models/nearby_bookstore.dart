class NearbyBookstore {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final bool? isOpenNow;
  final String? googleMapsUri;
  final double distanceMeters;

  const NearbyBookstore({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.isOpenNow,
    this.googleMapsUri,
    required this.distanceMeters,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  factory NearbyBookstore.fromPlacesJson(
    Map<String, dynamic> json, {
    required double distanceMeters,
  }) {
    final location = json['location'] as Map<String, dynamic>;
    final displayName = json['displayName'] as Map<String, dynamic>?;
    final openingHours = json['currentOpeningHours'] as Map<String, dynamic>?;

    return NearbyBookstore(
      name: displayName?['text'] as String? ?? '',
      address: json['formattedAddress'] as String? ?? '',
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      isOpenNow: openingHours?['openNow'] as bool?,
      googleMapsUri: json['googleMapsUri'] as String?,
      distanceMeters: distanceMeters,
    );
  }
}

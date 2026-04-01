import 'package:geolocator/geolocator.dart';

class GeolocationHelper {
  /// Retourne la position actuelle de l'utilisateur, ou null si refusée/indisponible.
  /// [onError] est appelé avec un message d'erreur localisé si la localisation échoue.
  static Future<Position?> getCurrentPosition({
    void Function(String message)? onError,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('enableLocationSettings');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        onError?.call('locationAccessRequired');
        return null;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return position;
    } catch (e) {
      onError?.call('geolocationError');
      return null;
    }
  }
}

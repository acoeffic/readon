import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/nearby_bookstore.dart';

class PlacesService {
  static const String _baseUrl = 'https://places.googleapis.com/v1/places:searchNearby';
  static String get _apiKey => Env.googlePlacesApiKey;

  /// Recherche les librairies à proximité via Google Places API (New).
  Future<List<NearbyBookstore>> searchNearbyBookstores({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    String languageCode = 'fr',
  }) async {
    try {
      debugPrint('Places API key (first 10): ${_apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length)}');
      debugPrint('Places API key length: ${_apiKey.length}');
      if (_apiKey.isEmpty) {
        debugPrint('ERROR: GOOGLE_PLACES_API_KEY is empty!');
        return [];
      }
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,'
              'places.location,places.rating,places.currentOpeningHours,'
              'places.googleMapsUri',
        },
        body: jsonEncode({
          'includedTypes': ['book_store'],
          'maxResultCount': 20,
          'languageCode': languageCode,
          'locationRestriction': {
            'circle': {
              'center': {
                'latitude': latitude,
                'longitude': longitude,
              },
              'radius': radiusMeters,
            },
          },
        }),
      );

      debugPrint('Google Places API status: ${response.statusCode}');
      debugPrint('Google Places API body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>?;

        if (places == null || places.isEmpty) {
          debugPrint('Google Places API: aucun résultat trouvé');
          return [];
        }

        final bookstores = places.map((place) {
          final loc = place['location'] as Map<String, dynamic>;
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            (loc['latitude'] as num).toDouble(),
            (loc['longitude'] as num).toDouble(),
          );
          return NearbyBookstore.fromPlacesJson(
            place as Map<String, dynamic>,
            distanceMeters: distance,
          );
        }).toList();

        bookstores.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return bookstores;
      } else {
        debugPrint('Erreur Google Places API: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Erreur searchNearbyBookstores: $e');
      return [];
    }
  }
}

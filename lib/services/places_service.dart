import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/nearby_bookstore.dart';

/// Résultat paginé d'une recherche de librairies.
class BookstoreSearchResult {
  final List<NearbyBookstore> bookstores;
  final String? nextPageToken;

  const BookstoreSearchResult({
    required this.bookstores,
    this.nextPageToken,
  });

  bool get hasMore => nextPageToken != null;
}

class PlacesService {
  static const String _searchTextUrl =
      'https://places.googleapis.com/v1/places:searchText';
  static String get _apiKey => Env.googlePlacesApiKey;

  /// Recherche les librairies à proximité via Google Places API (New) — Text Search.
  ///
  /// Utilise l'endpoint `searchText` qui supporte la pagination via [pageToken].
  /// Retourne un [BookstoreSearchResult] contenant les résultats et un éventuel
  /// token pour charger la page suivante.
  Future<BookstoreSearchResult> searchNearbyBookstores({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    String languageCode = 'fr',
    String? pageToken,
  }) async {
    try {
      debugPrint(
          'Places API key (first 10): ${_apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length)}');
      debugPrint('Places API key length: ${_apiKey.length}');
      if (_apiKey.isEmpty) {
        debugPrint('ERROR: GOOGLE_PLACES_API_KEY is empty!');
        return const BookstoreSearchResult(bookstores: []);
      }

      final textQuery = languageCode == 'fr' ? 'librairie' : 'bookstore';

      final bodyMap = <String, dynamic>{
        'textQuery': textQuery,
        'languageCode': languageCode,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radiusMeters,
          },
        },
      };

      if (pageToken != null) {
        bodyMap['pageToken'] = pageToken;
      }

      final response = await http.post(
        Uri.parse(_searchTextUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,'
              'places.location,places.rating,places.currentOpeningHours,'
              'places.googleMapsUri,nextPageToken',
        },
        body: jsonEncode(bodyMap),
      );

      debugPrint('Google Places API status: ${response.statusCode}');
      debugPrint('Google Places API body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>?;
        final nextToken = data['nextPageToken'] as String?;

        if (places == null || places.isEmpty) {
          debugPrint('Google Places API: aucun résultat trouvé');
          return const BookstoreSearchResult(bookstores: []);
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

        bookstores
            .sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

        return BookstoreSearchResult(
          bookstores: bookstores,
          nextPageToken: nextToken,
        );
      } else {
        debugPrint(
            'Erreur Google Places API: ${response.statusCode} ${response.body}');
        return const BookstoreSearchResult(bookstores: []);
      }
    } catch (e) {
      debugPrint('Erreur searchNearbyBookstores: $e');
      return const BookstoreSearchResult(bookstores: []);
    }
  }
}

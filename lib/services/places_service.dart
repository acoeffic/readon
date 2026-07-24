import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/nearby_bookstore.dart';

/// Résultat paginé d'une recherche de librairies.
class BookstoreSearchResult {
  final List<NearbyBookstore> bookstores;
  final String? nextPageToken;

  /// Message d'erreur si l'appel a échoué (réseau, clé refusée, API non
  /// activée…). `null` si l'appel a réussi — même avec zéro résultat.
  final String? errorMessage;

  const BookstoreSearchResult({
    required this.bookstores,
    this.nextPageToken,
    this.errorMessage,
  });

  bool get hasMore => nextPageToken != null;
  bool get hasError => errorMessage != null;
}

class PlacesService {
  static const String _searchTextUrl =
      'https://places.googleapis.com/v1/places:searchText';
  static String get _apiKey => Env.googlePlacesApiKey;

  /// Identifiant du bundle iOS, déclaré dans la restriction de la clé Google.
  static const String _iosBundleId = 'fr.lexday.app';

  /// Package Android, déclaré dans la restriction de la clé Google.
  static const String _androidPackage = 'com.acoeffic.lexday';

  /// En-têtes d'identité de plateforme à joindre aux appels REST.
  ///
  /// Le SDK Google Maps (carte) envoie ces infos automatiquement, mais un
  /// appel `http` brut ne le fait pas : sans elles, une clé restreinte par
  /// app renvoie `REQUEST_DENIED`. On reproduit donc le comportement du SDK.
  /// Sur Android, le couple package + empreinte SHA-1 est requis ; on ne
  /// l'ajoute que si l'empreinte est fournie (sinon comportement inchangé).
  Map<String, String> _appRestrictionHeaders() {
    if (Platform.isIOS) {
      return {'X-Ios-Bundle-Identifier': _iosBundleId};
    }
    if (Platform.isAndroid && Env.androidCertSha1.isNotEmpty) {
      return {
        'X-Android-Package': _androidPackage,
        'X-Android-Cert': Env.androidCertSha1,
      };
    }
    return const {};
  }

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
        return const BookstoreSearchResult(
          bookstores: [],
          errorMessage: 'GOOGLE_PLACES_API_KEY manquante',
        );
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
          ..._appRestrictionHeaders(),
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
        // Extraire le message d'erreur Google si présent (ex: REQUEST_DENIED).
        String detail = 'HTTP ${response.statusCode}';
        try {
          final err = jsonDecode(response.body) as Map<String, dynamic>;
          final msg = (err['error'] as Map<String, dynamic>?)?['message'];
          if (msg is String && msg.isNotEmpty) detail = msg;
        } catch (_) {}
        return BookstoreSearchResult(bookstores: const [], errorMessage: detail);
      }
    } catch (e) {
      debugPrint('Erreur searchNearbyBookstores: $e');
      return BookstoreSearchResult(
        bookstores: const [],
        errorMessage: e.toString(),
      );
    }
  }
}

// lib/utils/amazon_affiliate.dart
//
// Helper centralisé pour construire et ouvrir les liens Amazon affiliés.
// Stratégie : si on a un ISBN exploitable, on envoie l'utilisateur directement
// sur la fiche produit (`/dp/<ISBN-10>`) — sinon on retombe sur une recherche
// (`/s?k=<query>&i=stripbooks`). La fiche produit affiche la Buy Box et permet
// d'acheter en 1 clic, là où la recherche force l'utilisateur à choisir parmi
// plusieurs éditions concurrentes (perte de conversion + risque de mauvaise
// édition).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/analytics_service.dart';

/// Origine du clic Amazon. Sert de propriété `source` dans l'event
/// PostHog `amazon_link_clicked` — à utiliser pour les funnels de
/// conversion par surface.
enum AmazonClickSource {
  suggestionCard,
  bookDetail,
  prizeList,
  curatedList,
  chatCardChip,
  chatBuySheet;

  String get analyticsValue {
    switch (this) {
      case AmazonClickSource.suggestionCard:
        return 'suggestion_card';
      case AmazonClickSource.bookDetail:
        return 'book_detail';
      case AmazonClickSource.prizeList:
        return 'prize_list';
      case AmazonClickSource.curatedList:
        return 'curated_list';
      case AmazonClickSource.chatCardChip:
        return 'chat_card_chip';
      case AmazonClickSource.chatBuySheet:
        return 'chat_buy_sheet';
    }
  }
}

class AmazonAffiliate {
  static const String affiliateTag = 'lexday-21';
  static const String _host = 'www.amazon.fr';

  /// Construit l'URL Amazon affiliée pour un livre.
  ///
  /// - Si [isbn] est un ISBN-10 valide → `/dp/<isbn10>` (fiche produit directe)
  /// - Si [isbn] est un ISBN-13 valide en `978…` → conversion en ISBN-10 →
  ///   `/dp/<isbn10>`
  /// - Sinon → `/s?k=<query>&i=stripbooks` (recherche, query = title+author)
  static Uri urlForBook({
    String? isbn,
    required String title,
    String? author,
  }) {
    final isbn10 = _toIsbn10(isbn);
    if (isbn10 != null) {
      return Uri.https(_host, '/dp/$isbn10', {'tag': affiliateTag});
    }
    final query = [title, if (author != null && author.isNotEmpty) author]
        .join(' ')
        .trim();
    return Uri.https(_host, '/s', {
      'k': query,
      'i': 'stripbooks',
      'tag': affiliateTag,
    });
  }

  /// Ouvre la fiche/recherche Amazon dans le navigateur externe (ou l'app
  /// Amazon installée, via universal link), et log un event analytics
  /// `amazon_link_clicked` avec la surface d'origine et le type de lien
  /// servi (`product` quand on a un ISBN exploitable, `search` sinon).
  static Future<void> openForBook({
    String? isbn,
    required String title,
    String? author,
    required AmazonClickSource source,
  }) async {
    final isbn10 = _toIsbn10(isbn);
    final url = urlForBook(isbn: isbn, title: title, author: author);

    unawaited(AnalyticsService().track(
      AnalyticsEvent.amazonLinkClicked,
      properties: {
        'source': source.analyticsValue,
        'link_type': isbn10 != null ? 'product' : 'search',
        'has_isbn': isbn10 != null,
      },
    ));

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('AmazonAffiliate.openForBook failed: $e');
    }
  }

  /// Normalise et convertit un ISBN brut (avec ou sans tirets/espaces) en
  /// ISBN-10. Retourne `null` si l'entrée n'est pas un ISBN exploitable pour
  /// `/dp/`.
  static String? _toIsbn10(String? raw) {
    if (raw == null) return null;
    final clean = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (clean.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(clean)) {
      return clean;
    }
    if (clean.length == 13 &&
        RegExp(r'^\d{13}$').hasMatch(clean) &&
        clean.startsWith('978')) {
      return _isbn13ToIsbn10(clean);
    }
    return null;
  }

  /// Conversion déterministe ISBN-13 (préfixe 978) → ISBN-10.
  /// Reprend les 9 chiffres significatifs et recalcule la clé selon
  /// l'algorithme ISBN-10 (somme pondérée modulo 11, 10 → 'X').
  static String _isbn13ToIsbn10(String isbn13) {
    final body = isbn13.substring(3, 12);
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(body[i]) * (10 - i);
    }
    final remainder = (11 - (sum % 11)) % 11;
    final checkChar = remainder == 10 ? 'X' : remainder.toString();
    return '$body$checkChar';
  }
}

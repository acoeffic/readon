// lib/utils/amazon_affiliate.dart
//
// Helper centralisé pour construire et ouvrir les liens Amazon affiliés.
// Stratégie : recherche Amazon (`/s?k=<query>&i=stripbooks`). Si on a un ISBN
// valide (clé de contrôle vérifiée), on cherche par ISBN — ce qui mène
// quasi toujours directement au bon livre — sinon on cherche par titre+auteur.
//
// NB : on N'utilise PAS `/dp/<ISBN-10>` (fiche produit directe). Cette approche
// suppose que l'ASIN Amazon == l'ISBN-10, ce qui n'est pas fiable : un ISBN
// valide mais absent d'amazon.fr (édition épuisée, autre ASIN, poche vs broché)
// renvoie la page d'erreur « chien d'Amazon ». La recherche, elle, ne tombe
// jamais sur cette page.

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
  /// On cherche TOUJOURS par titre + auteur : `/s?k=<title author>&i=stripbooks`.
  ///
  /// On n'utilise volontairement PAS l'ISBN dans la requête : la base contient
  /// des ISBN d'éditions étrangères (ex. 978-1 = anglais) qui n'existent pas sur
  /// amazon.fr → la recherche par ISBN exact renvoie « aucun résultat ». La
  /// recherche titre+auteur retombe presque toujours sur une édition achetable.
  /// [isbn] est conservé uniquement pour l'analytics (`has_isbn`).
  static Uri urlForBook({
    String? isbn,
    required String title,
    String? author,
  }) {
    final query = [title, if (author != null && author.isNotEmpty) author]
        .join(' ')
        .trim();
    return Uri.https(_host, '/s', {
      'k': query,
      'i': 'stripbooks',
      'tag': affiliateTag,
    });
  }

  /// Ouvre la recherche Amazon (titre + auteur) dans le navigateur externe
  /// (ou l'app Amazon installée, via universal link), et log un event analytics
  /// `amazon_link_clicked` avec la surface d'origine et `has_isbn` (le livre
  /// avait-il un ISBN valide en base, pour suivre la couverture des données).
  static Future<void> openForBook({
    String? isbn,
    required String title,
    String? author,
    required AmazonClickSource source,
  }) async {
    final validIsbn = _normalizeValidIsbn(isbn);
    final url = urlForBook(isbn: isbn, title: title, author: author);

    unawaited(AnalyticsService().track(
      AnalyticsEvent.amazonLinkClicked,
      properties: {
        'source': source.analyticsValue,
        'link_type': 'text_search',
        'has_isbn': validIsbn != null,
      },
    ));

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('AmazonAffiliate.openForBook failed: $e');
    }
  }

  /// Normalise un ISBN brut (avec ou sans tirets/espaces) et le renvoie
  /// nettoyé UNIQUEMENT si sa clé de contrôle est valide (ISBN-10 ou ISBN-13).
  /// Retourne `null` sinon → on retombera sur une recherche titre+auteur.
  static String? _normalizeValidIsbn(String? raw) {
    if (raw == null) return null;
    final clean = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (clean.length == 10 && _isValidIsbn10(clean)) return clean;
    if (clean.length == 13 && _isValidIsbn13(clean)) return clean;
    return null;
  }

  /// Valide la clé de contrôle d'un ISBN-10 : somme pondérée (10..1) ≡ 0 mod 11,
  /// dernier caractère 'X' = 10.
  static bool _isValidIsbn10(String s) {
    if (!RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final c = s[i];
      final value = (i == 9 && c == 'X') ? 10 : int.parse(c);
      sum += value * (10 - i);
    }
    return sum % 11 == 0;
  }

  /// Valide la clé de contrôle d'un ISBN-13 : somme pondérée (1,3,1,3…) ≡ 0
  /// mod 10.
  static bool _isValidIsbn13(String s) {
    if (!RegExp(r'^\d{13}$').hasMatch(s)) return false;
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final value = int.parse(s[i]);
      sum += (i.isEven) ? value : value * 3;
    }
    return sum % 10 == 0;
  }
}

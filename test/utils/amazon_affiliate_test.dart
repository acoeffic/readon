// Tests du builder d'URL Amazon affiliée.
//
// On teste `urlForBook` (fonction pure, sans plugins). Stratégie : recherche
// TOUJOURS par titre + auteur (l'ISBN n'entre pas dans la requête car la base
// contient des ISBN d'éditions étrangères absentes d'amazon.fr).
// `openForBook` n'est pas testé ici car il déclenche url_launcher + analytics.

import 'package:flutter_test/flutter_test.dart';
import 'package:lexday/utils/amazon_affiliate.dart';

void main() {
  group('AmazonAffiliate.urlForBook', () {
    test('reste toujours sur la recherche /s (jamais /dp)', () {
      final uri = AmazonAffiliate.urlForBook(
        isbn: '9782070360024',
        title: "L'Étranger",
        author: 'Albert Camus',
      );
      expect(uri.host, 'www.amazon.fr');
      expect(uri.path, '/s');
      expect(uri.queryParameters['i'], 'stripbooks');
    });

    test('inclut toujours le tag affilié', () {
      final withIsbn = AmazonAffiliate.urlForBook(
        isbn: '9782070360024',
        title: 'X',
      );
      final withoutIsbn = AmazonAffiliate.urlForBook(
        isbn: null,
        title: 'X',
        author: 'Y',
      );
      expect(withIsbn.queryParameters['tag'], AmazonAffiliate.affiliateTag);
      expect(withoutIsbn.queryParameters['tag'], AmazonAffiliate.affiliateTag);
    });

    test('recherche par titre + auteur, jamais par ISBN', () {
      final uri = AmazonAffiliate.urlForBook(
        isbn: '9782070360024',
        title: "L'Étranger",
        author: 'Albert Camus',
      );
      expect(uri.queryParameters['k'], "L'Étranger Albert Camus");
    });

    test('ISBN étranger (978-1) ignoré → titre + auteur quand même', () {
      // 9781511433518 = édition anglaise/US absente d'amazon.fr.
      final uri = AmazonAffiliate.urlForBook(
        isbn: '9781511433518',
        title: 'The Knowledge',
        author: 'Lewis Dartnell',
      );
      expect(uri.queryParameters['k'], 'The Knowledge Lewis Dartnell');
    });

    test('ISBN nul → titre + auteur', () {
      final uri = AmazonAffiliate.urlForBook(
        isbn: null,
        title: 'Sapiens',
        author: 'Yuval Noah Harari',
      );
      expect(uri.queryParameters['k'], 'Sapiens Yuval Noah Harari');
    });

    test('auteur absent → query = titre seul', () {
      final uri = AmazonAffiliate.urlForBook(
        isbn: null,
        title: 'Sapiens',
        author: '',
      );
      expect(uri.queryParameters['k'], 'Sapiens');
    });

    test('auteur null → query = titre seul', () {
      final uri = AmazonAffiliate.urlForBook(
        title: 'Sapiens',
      );
      expect(uri.queryParameters['k'], 'Sapiens');
    });
  });
}

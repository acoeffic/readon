import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KindleReadingData {
  final int? booksReadThisYear;
  final int? currentStreak;
  final int? weeksStreak;
  final int? daysStreak;
  final int? longestStreak;
  final int? totalDaysRead;
  final int? totalMinutesRead;
  final String? lastSyncDate;
  final List<KindleBookProgress> books;

  KindleReadingData({
    this.booksReadThisYear,
    this.currentStreak,
    this.weeksStreak,
    this.daysStreak,
    this.longestStreak,
    this.totalDaysRead,
    this.totalMinutesRead,
    this.lastSyncDate,
    this.books = const [],
  });

  factory KindleReadingData.fromJson(Map<String, dynamic> json) {
    return KindleReadingData(
      booksReadThisYear: json['booksReadThisYear'] as int?,
      currentStreak: json['currentStreak'] as int?,
      weeksStreak: json['weeksStreak'] as int?,
      daysStreak: json['daysStreak'] as int?,
      longestStreak: json['longestStreak'] as int?,
      totalDaysRead: json['totalDaysRead'] as int?,
      totalMinutesRead: json['totalMinutesRead'] as int?,
      lastSyncDate: json['lastSyncDate'] as String?,
      books: (json['books'] as List<dynamic>?)
              ?.map((b) => KindleBookProgress.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'booksReadThisYear': booksReadThisYear,
        'currentStreak': currentStreak,
        'weeksStreak': weeksStreak,
        'daysStreak': daysStreak,
        'longestStreak': longestStreak,
        'totalDaysRead': totalDaysRead,
        'totalMinutesRead': totalMinutesRead,
        'lastSyncDate': lastSyncDate,
        'books': books.map((b) => b.toJson()).toList(),
      };

  bool get isEmpty =>
      booksReadThisYear == null &&
      currentStreak == null &&
      weeksStreak == null &&
      daysStreak == null;
}

class KindleBookProgress {
  final String title;
  final String? author;
  final int? percentComplete;
  final String? lastReadDate;
  final String? coverUrl;

  KindleBookProgress({
    required this.title,
    this.author,
    this.percentComplete,
    this.lastReadDate,
    this.coverUrl,
  });

  factory KindleBookProgress.fromJson(Map<String, dynamic> json) {
    return KindleBookProgress(
      title: json['title'] as String? ?? 'Unknown',
      author: json['author'] as String?,
      percentComplete: json['percentComplete'] as int?,
      lastReadDate: json['lastReadDate'] as String?,
      coverUrl: json['coverUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'percentComplete': percentComplete,
        'lastReadDate': lastReadDate,
        'coverUrl': coverUrl,
      };
}

class KindleWebViewService {
  static const String _cacheKey = 'kindle_reading_data';
  static const String _lastSyncKey = 'kindle_last_sync';

  /// Script de debug : capture le contenu textuel de la page pour analyse
  static const String debugScript = '''
    (function() {
      try {
        return JSON.stringify({
          title: document.title,
          url: window.location.href,
          bodyText: document.body.innerText.substring(0, 3000),
          html: document.body.innerHTML.substring(0, 5000)
        });
      } catch(e) {
        return JSON.stringify({ error: e.message });
      }
    })();
  ''';

  /// JavaScript à injecter dans la page Reading Insights pour extraire les données.
  /// Adapté à la structure réelle de la page Amazon Reading Insights.
  static const String extractionScript = '''
    (function() {
      try {
        var data = {
          booksReadThisYear: null,
          currentStreak: null,
          longestStreak: null,
          weeksStreak: null,
          daysStreak: null,
          totalDaysRead: null,
          totalMinutesRead: null,
          books: []
        };

        var bodyText = document.body.innerText;
        var lines = bodyText.split('\\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 0; });

        // Pattern 1 : "Weeks in a row" suivi ou précédé d'un nombre
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].toLowerCase();

          // "Weeks in a row" — le nombre est sur la ligne suivante ou précédente
          if (line.includes('weeks in a row') || line.includes('semaines')) {
            // Chercher le nombre sur la ligne suivante
            if (i + 1 < lines.length) {
              var nextNum = lines[i + 1].match(/^(\\d+)/);
              if (nextNum) data.weeksStreak = parseInt(nextNum[1]);
            }
            // Ou sur la ligne précédente
            if (!data.weeksStreak && i > 0) {
              var prevNum = lines[i - 1].match(/^(\\d+)/);
              if (prevNum) data.weeksStreak = parseInt(prevNum[1]);
            }
          }

          // "Days in a row" — pareil
          if (line.includes('days in a row') || line.includes('jours consécutifs')) {
            if (i + 1 < lines.length) {
              var nextNum = lines[i + 1].match(/^(\\d+)/);
              if (nextNum) data.daysStreak = parseInt(nextNum[1]);
            }
            if (!data.daysStreak && i > 0) {
              var prevNum = lines[i - 1].match(/^(\\d+)/);
              if (prevNum) data.daysStreak = parseInt(prevNum[1]);
            }
          }

          // "X titles read" ou "X livres lus"
          var titlesMatch = lines[i].match(/(\\d+)\\s*titles?\\s*read/i);
          if (titlesMatch) {
            data.booksReadThisYear = parseInt(titlesMatch[1]);
          }
          var livresMatch = lines[i].match(/(\\d+)\\s*livres?\\s*lus?/i);
          if (livresMatch) {
            data.booksReadThisYear = parseInt(livresMatch[1]);
          }

          // "You read X more days" — info sur les jours lus ce mois
          var daysMatch = lines[i].match(/read\\s+(\\d+)\\s+more\\s+days?/i);
          if (daysMatch && !data.totalDaysRead) {
            data.totalDaysRead = parseInt(daysMatch[1]);
          }
        }

        // Pattern 2 : chercher les nombres juste avant "Weeks in a row" / "Days in a row" dans le DOM
        var allElements = document.querySelectorAll('span, div, p, h1, h2, h3, h4, strong, b');
        var prevNumEl = null;
        allElements.forEach(function(el) {
          var text = el.textContent.trim();
          if (text.length > 150) return;

          var pureNum = text.match(/^(\\d+)\\.?\\s*\\.?\\s*\$/);
          if (pureNum) {
            prevNumEl = parseInt(pureNum[1]);
            return;
          }

          if (prevNumEl !== null) {
            var lower = text.toLowerCase();
            if ((lower === 'weeks in a row' || lower.includes('weeks in a row')) && !data.weeksStreak) {
              data.weeksStreak = prevNumEl;
            } else if ((lower === 'days in a row' || lower.includes('days in a row')) && !data.daysStreak) {
              data.daysStreak = prevNumEl;
            }
            prevNumEl = null;
          }
        });

        // Utiliser directement daysStreak comme currentStreak
        if (data.daysStreak) {
          data.currentStreak = data.daysStreak;
        }

        // Pattern 3 : Extraire les livres depuis les liens produit Amazon
        var seen = new Set();
        var linkSelectors = 'a[href*="/dp/"], a[href*="/gp/product/"], a[href*="/B0"]';
        document.querySelectorAll(linkSelectors).forEach(function(a) {
          var href = a.getAttribute('href') || '';
          if (href.includes('/help') || href.includes('/customer') || href.includes('/ref=nav')) return;
          var img = a.querySelector('img[alt]');
          if (img) {
            var alt = img.alt.trim();
            if (alt.length > 3 && alt.length < 200 && !seen.has(alt.toLowerCase())) {
              seen.add(alt.toLowerCase());
              data.books.push({ title: alt, author: null, percentComplete: 100 });
            }
          }
        });

        return JSON.stringify(data);
      } catch(e) {
        return JSON.stringify({ error: e.message });
      }
    })();
  ''';

  /// Script pour récupérer les années disponibles dans les onglets
  static const String getAvailableYearsScript = '''
    (function() {
      try {
        var years = [];
        // Chercher les éléments qui contiennent des années (2020-2026)
        var elements = document.querySelectorAll('a, button, span, div, li');
        elements.forEach(function(el) {
          var text = el.textContent.trim();
          if (/^(20[2-9]\\d)\$/.test(text)) {
            var year = parseInt(text);
            if (years.indexOf(year) === -1) {
              years.push(year);
            }
          }
        });
        years.sort(function(a, b) { return b - a; }); // Plus récent en premier
        return JSON.stringify(years);
      } catch(e) {
        return JSON.stringify([]);
      }
    })();
  ''';

  /// Script pour cliquer sur un onglet d'année spécifique
  static String clickYearTabScript(int year) {
    return '''
      (function() {
        var elements = document.querySelectorAll('a, button, span, div, li');
        for (var i = 0; i < elements.length; i++) {
          var text = elements[i].textContent.trim();
          if (text === '$year') {
            elements[i].click();
            return 'clicked';
          }
        }
        return 'not_found';
      })();
    ''';
  }

  /// Script synchrone pour vérifier si la bibliothèque est chargée
  /// Appelé en boucle depuis Dart (pas d'async/await car iOS ne le supporte pas)
  static const String checkLibraryLoadedScript = '''
    (function() {
      try {
        var imgCount = document.querySelectorAll('img').length;
        var imgWithAlt = document.querySelectorAll('img[alt]').length;
        var hasBooks = document.querySelectorAll('[data-asin], [class*="book"], [class*="Book"]').length > 0;
        var hasAmazonImages = document.querySelectorAll('img[src*="images-na"], img[src*="m.media-amazon"], img[src*="images-amazon"]').length > 0;
        var hasGrid = document.querySelectorAll('[class*="grid"], [class*="library"], [class*="collection"]').length > 0;
        var bodyLength = document.body.innerText.length;

        var loaded = hasBooks || hasAmazonImages || (hasGrid && imgCount > 3) || imgWithAlt > 5 || bodyLength > 1000;

        return JSON.stringify({
          loaded: loaded,
          imgCount: imgCount,
          imgWithAlt: imgWithAlt,
          hasBooks: hasBooks,
          hasAmazonImages: hasAmazonImages,
          bodyLength: bodyLength
        });
      } catch(e) {
        return JSON.stringify({ loaded: false, error: e.message });
      }
    })();
  ''';

  /// Script de debug pour trouver où Kindle Cloud Reader stocke la progression
  /// Cherche dans : variables JS globales, DOM complet, barres de progression, localStorage
  static const String debugKindleLibraryScript = '''
    (function() {
      try {
        var info = {
          progressInDOM: [],
          jsGlobalState: [],
          localStorageKeys: [],
          firstBookDOM: null,
          percentInText: []
        };

        // 1. Chercher les variables globales JavaScript (état React/Redux/etc.)
        var globalKeys = Object.keys(window).filter(function(k) {
          return k.startsWith('__') || k.includes('state') || k.includes('State') ||
                 k.includes('store') || k.includes('Store') || k.includes('data') ||
                 k.includes('Data') || k.includes('app') || k.includes('App') ||
                 k.includes('kindle') || k.includes('Kindle') || k.includes('library') ||
                 k.includes('Library');
        });
        globalKeys.forEach(function(k) {
          try {
            var val = window[k];
            var type = typeof val;
            var preview = '';
            if (type === 'object' && val !== null) {
              preview = JSON.stringify(val).substring(0, 200);
            } else if (type === 'string') {
              preview = val.substring(0, 200);
            }
            if (preview.length > 0) {
              info.jsGlobalState.push({ key: k, type: type, preview: preview });
            }
          } catch(e) {}
        });

        // 2. Chercher dans localStorage/sessionStorage
        try {
          for (var i = 0; i < localStorage.length && i < 20; i++) {
            var key = localStorage.key(i);
            var val = localStorage.getItem(key);
            if (val && (key.includes('progress') || key.includes('book') ||
                key.includes('library') || key.includes('position') ||
                key.includes('kindle') || key.includes('percent') ||
                key.includes('page') || key.includes('loc'))) {
              info.localStorageKeys.push({ key: key, value: val.substring(0, 300) });
            }
          }
        } catch(e) {}

        // 3. Analyser le DOM du premier livre trouvé
        // Trouver un élément qui contient un titre de livre connu (du bodyText)
        var bodyText = document.body.innerText || '';
        var lines = bodyText.split('\\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 0; });

        var firstTitle = null;
        for (var i = 0; i < lines.length - 1; i++) {
          if (lines[i].length > 10 && lines[i].length < 200) {
            for (var j = i + 1; j < Math.min(i + 4, lines.length); j++) {
              if (lines[j] === lines[i]) {
                firstTitle = lines[i];
                break;
              }
            }
            if (firstTitle) break;
          }
        }

        if (firstTitle) {
          // Trouver l'élément DOM contenant ce titre
          var allEls = document.querySelectorAll('*');
          for (var i = 0; i < allEls.length; i++) {
            var el = allEls[i];
            if (el.children.length < 3 && el.textContent.trim() === firstTitle) {
              // Remonter pour trouver le conteneur du livre
              var container = el;
              for (var p = 0; p < 5; p++) {
                if (container.parentElement) container = container.parentElement;
                // Un bon conteneur a une taille raisonnable
                if (container.children.length >= 2 && container.children.length <= 10) break;
              }

              // Capturer le HTML interne du conteneur du livre
              info.firstBookDOM = {
                title: firstTitle,
                containerTag: container.tagName,
                containerClass: (container.className || '').toString().substring(0, 150),
                innerHTML: container.innerHTML.substring(0, 2000),
                outerHTML: container.outerHTML.substring(0, 500),
                childCount: container.children.length,
                allDataAttrs: {}
              };

              // Collecter tous les data-attributes du conteneur et ses enfants
              var descendants = container.querySelectorAll('*');
              descendants.forEach(function(d) {
                for (var a = 0; a < d.attributes.length; a++) {
                  var attr = d.attributes[a];
                  if (attr.name.startsWith('data-') || attr.name === 'aria-valuenow' ||
                      attr.name === 'aria-valuemax' || attr.name === 'role') {
                    info.firstBookDOM.allDataAttrs[attr.name] = attr.value.substring(0, 100);
                  }
                }
              });

              break;
            }
          }
        }

        // 4. Chercher tous les éléments avec style width en %
        document.querySelectorAll('[style]').forEach(function(el) {
          var style = el.getAttribute('style') || '';
          var widthMatch = style.match(/width:\\s*(\\d+(\\.\\d+)?)\\s*%/);
          if (widthMatch && info.progressInDOM.length < 15) {
            var parent = el.parentElement;
            info.progressInDOM.push({
              width: widthMatch[1] + '%',
              tag: el.tagName,
              class: (el.className || '').toString().substring(0, 80),
              parentClass: parent ? (parent.className || '').toString().substring(0, 80) : '',
              nearText: (parent ? parent.textContent : el.textContent || '').trim().substring(0, 100)
            });
          }
        });

        // 5. Chercher % dans le texte
        var percentRegex = /\\d+\\s*%/g;
        var match;
        while ((match = percentRegex.exec(bodyText)) !== null && info.percentInText.length < 10) {
          var start = Math.max(0, match.index - 50);
          var end = Math.min(bodyText.length, match.index + match[0].length + 50);
          info.percentInText.push(bodyText.substring(start, end).replace(/\\n/g, ' | '));
        }

        return JSON.stringify(info);
      } catch(e) {
        return JSON.stringify({ error: e.message });
      }
    })();
  ''';

  /// Script pour extraire les livres depuis read.amazon.com/kindle-library
  /// Approche: trouver les conteneurs de livres via les images Amazon, puis extraire le texte visible
  static const String extractKindleLibraryScript = '''
    (function() {
      try {
        var books = [];
        var seen = new Set();
        var debugInfo = { imagesFound: 0, booksExtracted: 0, containerSamples: [] };

        // Fonction pour trouver le conteneur "book card" à partir d'une image
        function findBookContainer(img) {
          var el = img;
          for (var i = 0; i < 10; i++) {
            if (!el.parentElement) break;
            el = el.parentElement;

            // Un bon conteneur a plusieurs enfants et une taille raisonnable
            var rect = el.getBoundingClientRect();
            var hasMultipleChildren = el.children.length >= 2;
            var reasonableSize = rect.width > 80 && rect.width < 500 && rect.height > 100 && rect.height < 600;

            // Vérifier si ce conteneur a du texte visible (pas seulement l'image)
            var textContent = '';
            el.querySelectorAll('*').forEach(function(child) {
              if (child.tagName !== 'IMG' && child.tagName !== 'SCRIPT' && child.tagName !== 'STYLE') {
                var t = (child.innerText || '').trim();
                if (t.length > 0 && t.length < 200) textContent += t + ' ';
              }
            });

            if (hasMultipleChildren && reasonableSize && textContent.length > 5) {
              return el;
            }
          }
          return null;
        }

        // Fonction pour extraire titre et auteur depuis le texte visible d'un conteneur
        function extractBookInfo(container, img) {
          var result = { title: null, author: null };

          // Utiliser l'attribut alt de l'image comme indice pour le titre
          var imgAlt = (img.getAttribute('alt') || '').trim();

          // Collecter tous les textes visibles avec leurs styles
          var allElements = container.querySelectorAll('span, p, div, h1, h2, h3, h4, h5, a, strong, b, em');
          var textElements = [];

          allElements.forEach(function(el) {
            if (el.contains(img) || el.tagName === 'IMG') return;
            if (el.querySelectorAll('span, p, div, h1, h2, h3, h4, h5, a').length > 2) return;

            var text = (el.innerText || el.textContent || '').trim();
            text = text.split('\\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 0; })[0] || '';

            if (text.length < 2 || text.length >= 200) return;

            var lower = text.toLowerCase();
            // Filtrer les textes de navigation/UI (liste étendue)
            if (lower === 'kindle' || lower === 'downloaded' || lower === 'download' ||
                lower === 'read now' || lower === 'read' || lower === 'more' ||
                lower === 'sample' || lower === 'new' || lower === 'delete' ||
                lower === 'deliver' || lower === 'return' || lower === 'buy' ||
                lower === 'open' || lower === 'remove' || lower === 'go to' ||
                lower === 'not started' || lower === 'lire' || lower === 'ouvrir' ||
                lower === 'supprimer' || lower === 'retourner' || lower === 'acheter' ||
                lower.includes('filter') || lower.includes('sort') ||
                lower.includes('sign in') || lower.includes('skip') ||
                lower.includes('sync') || lower.includes('archive') ||
                lower.includes('manage') || lower.includes('settings') ||
                text.match(/^\\d+\\s*%\$/) || text.match(/^\\d+\$/)) {
              return;
            }

            // Récupérer le style calculé pour les heuristiques
            var style = window.getComputedStyle(el);
            var fontSize = parseFloat(style.fontSize) || 14;
            var hasByPrefix = /^(by|par|de)\\s+/i.test(text);

            // Éviter les doublons
            var isDuplicate = false;
            for (var i = 0; i < textElements.length; i++) {
              if (textElements[i].text === text) { isDuplicate = true; break; }
            }
            if (!isDuplicate) {
              textElements.push({
                text: text,
                fontSize: fontSize,
                hasByPrefix: hasByPrefix
              });
            }
          });

          // Stratégie 1 : Chercher un préfixe explicite "By" / "par" / "de"
          var byElement = null;
          for (var i = 0; i < textElements.length; i++) {
            if (textElements[i].hasByPrefix) { byElement = textElements[i]; break; }
          }
          if (byElement) {
            result.author = byElement.text.replace(/^(by|par|de)\\s+/i, '').trim();
            for (var i = 0; i < textElements.length; i++) {
              if (!textElements[i].hasByPrefix) { result.title = textElements[i].text; break; }
            }
            return result;
          }

          // Stratégie 2 : Utiliser le alt de l'image pour identifier le titre
          // puis l'auteur est le texte restant le plus probable
          if (imgAlt.length > 3) {
            var altLower = imgAlt.toLowerCase();
            var foundTitle = false;
            for (var i = 0; i < textElements.length; i++) {
              var tLower = textElements[i].text.toLowerCase();
              if (tLower === altLower || altLower.includes(tLower) || tLower.includes(altLower)) {
                result.title = textElements[i].text;
                foundTitle = true;
                // L'auteur est le prochain texte différent du titre
                for (var j = 0; j < textElements.length; j++) {
                  if (j !== i) { result.author = textElements[j].text; break; }
                }
                break;
              }
            }
            if (foundTitle) return result;
          }

          // Stratégie 3 : Si l'image a un alt, l'utiliser directement comme titre
          // et prendre le premier texte restant (qui n'est pas le titre) comme auteur
          if (imgAlt.length > 3) {
            result.title = imgAlt;
            for (var i = 0; i < textElements.length; i++) {
              var tLower = textElements[i].text.toLowerCase();
              // Ignorer le texte qui ressemble au titre
              if (tLower === imgAlt.toLowerCase()) continue;
              if (textElements[i].text.length >= 3) {
                result.author = textElements[i].text;
                break;
              }
            }
            if (result.author) return result;
          }

          // Stratégie 4 : Heuristique par taille de police
          // Le titre est généralement le texte le plus grand
          if (textElements.length >= 2) {
            var sorted = textElements.slice().sort(function(a, b) { return b.fontSize - a.fontSize; });
            result.title = sorted[0].text;
            // L'auteur est le texte avec une taille plus petite
            for (var i = 1; i < sorted.length; i++) {
              if (sorted[i].text.length >= 3) {
                result.author = sorted[i].text;
                break;
              }
            }
          } else if (textElements.length === 1) {
            result.title = textElements[0].text;
          }

          return result;
        }

        // Parcourir toutes les images Amazon (couvertures de livres)
        document.querySelectorAll('img').forEach(function(img) {
          var src = img.getAttribute('src') || '';

          // Filtrer uniquement les images de couverture Amazon
          if (!src.includes('m.media-amazon') &&
              !src.includes('images-na.ssl-images-amazon') &&
              !src.includes('images-amazon') &&
              !src.includes('ssl-images-amazon')) return;

          debugInfo.imagesFound++;

          // Ignorer les petites icônes
          var rect = img.getBoundingClientRect();
          if (rect.width < 40 || rect.height < 40) return;

          // Trouver le conteneur du livre
          var container = findBookContainer(img);
          if (!container) {
            // Fallback: utiliser le parent direct plusieurs niveaux
            container = img.parentElement;
            for (var i = 0; i < 4 && container; i++) {
              container = container.parentElement;
            }
          }

          if (!container) return;

          // Extraire titre et auteur
          var info = extractBookInfo(container, img);

          // Debug: capturer les 3 premiers conteneurs
          if (debugInfo.containerSamples.length < 3) {
            var sampleTexts = [];
            container.querySelectorAll('*').forEach(function(el) {
              var t = (el.innerText || '').trim().split('\\n')[0];
              if (t.length > 2 && t.length < 100 && !sampleTexts.includes(t)) {
                sampleTexts.push(t);
              }
            });
            debugInfo.containerSamples.push(sampleTexts.slice(0, 5));
          }

          if (!info.title || info.title.length < 2) return;

          var titleLower = info.title.toLowerCase();

          // Éviter les doublons
          if (seen.has(titleLower)) return;
          seen.add(titleLower);

          books.push({
            title: info.title,
            author: info.author,
            percentComplete: null,
            coverUrl: src
          });
        });

        debugInfo.booksExtracted = books.length;

        return JSON.stringify({ books: books, count: books.length, debug: debugInfo });
      } catch(e) {
        return JSON.stringify({ books: [], count: 0, error: e.message });
      }
    })();
  ''';

  /// Script pour extraire les livres visibles sur la page actuelle (Reading Insights)
  /// Cible les liens produits Amazon et les images de couverture
  static const String extractBooksScript = '''
    (function() {
      try {
        var books = [];
        var seen = new Set();

        // Chercher le nombre de titres lus
        var bodyText = document.body.innerText;
        var titlesMatch = bodyText.match(/(\\d+)\\s*titles?\\s*read/i);
        var titleCount = titlesMatch ? parseInt(titlesMatch[1]) : 0;

        // Fonction utilitaire pour trouver l'auteur près d'un lien produit
        function findAuthorNearLink(linkEl) {
          // Remonter au conteneur parent du livre
          var container = linkEl;
          for (var p = 0; p < 5; p++) {
            if (!container.parentElement) break;
            container = container.parentElement;
            // Un bon conteneur a du texte et n'est pas trop grand
            if (container.children.length >= 2 && container.children.length <= 15) {
              var texts = [];
              container.querySelectorAll('span, p, div, a, strong, em').forEach(function(el) {
                if (el.contains(linkEl) && el !== linkEl) return;
                var t = (el.innerText || el.textContent || '').trim();
                t = t.split('\\n')[0].trim();
                if (t.length >= 3 && t.length < 150) {
                  var lower = t.toLowerCase();
                  if (lower === 'kindle' || lower === 'read' || lower === 'read now' ||
                      lower.includes('amazon') || lower.includes('sign') ||
                      lower.includes('cart') || /^\\d+\$/.test(t) || /^\\d+\\s*%\$/.test(t)) return;
                  if (texts.indexOf(t) === -1) texts.push(t);
                }
              });
              // Chercher un texte avec préfixe "By" / "par"
              for (var i = 0; i < texts.length; i++) {
                if (/^(by|par|de)\\s+/i.test(texts[i])) {
                  return texts[i].replace(/^(by|par|de)\\s+/i, '').trim();
                }
              }
              // Sinon le 2e texte distinct (le 1er est souvent le titre)
              if (texts.length >= 2) return texts[1];
            }
          }
          return null;
        }

        // Méthode 1 : Extraire depuis les liens produit Amazon
        // Couvre /dp/, /gp/product/, et les ASINs (/B0...)
        var linkSelectors = 'a[href*="/dp/"], a[href*="/gp/product/"], a[href*="/B0"]';
        document.querySelectorAll(linkSelectors).forEach(function(a) {
          var href = a.getAttribute('href') || '';
          // Exclure les liens de navigation/menu
          if (href.includes('/help') || href.includes('/customer') || href.includes('/ref=nav')) return;

          var img = a.querySelector('img[alt]');
          if (img) {
            var alt = img.alt.trim();
            if (alt.length > 3 && alt.length < 200 && !seen.has(alt.toLowerCase())) {
              seen.add(alt.toLowerCase());
              var author = findAuthorNearLink(a);
              books.push({ title: alt, author: author, percentComplete: 100 });
            }
          } else {
            var text = a.textContent.trim();
            if (text.length > 3 && text.length < 100 &&
                !text.toLowerCase().includes('amazon') &&
                !text.toLowerCase().includes('kindle') &&
                !text.toLowerCase().includes('sign') &&
                !text.toLowerCase().includes('cart') &&
                !seen.has(text.toLowerCase())) {
              seen.add(text.toLowerCase());
              var author = findAuthorNearLink(a);
              books.push({ title: text, author: author, percentComplete: 100 });
            }
          }
        });

        // Méthode 2 : Si on a trouvé moins de livres que le titleCount,
        // chercher les images de couverture dans la section livres
        if (books.length < titleCount) {
          // Trouver la section "titles read" et remonter au conteneur
          var allEls = document.querySelectorAll('*');
          var titlesSection = null;
          for (var i = 0; i < allEls.length; i++) {
            var el = allEls[i];
            var t = el.textContent.trim();
            if (el.children.length < 5 && t.match(/^\\d+\\s*titles?\\s*read\$/i)) {
              // Remonter de plusieurs niveaux pour trouver le conteneur
              titlesSection = el;
              for (var j = 0; j < 5; j++) {
                if (titlesSection.parentElement) {
                  titlesSection = titlesSection.parentElement;
                  // Si ce parent contient des images de livres, c'est le bon
                  if (titlesSection.querySelectorAll('img[alt]').length >= 2) break;
                }
              }
              break;
            }
          }

          if (titlesSection) {
            titlesSection.querySelectorAll('img[alt]').forEach(function(img) {
              var alt = img.alt.trim();
              // Filtrer les non-livres
              if (alt.length > 3 && alt.length < 200 &&
                  !alt.toLowerCase().includes('amazon') &&
                  !alt.toLowerCase().includes('logo') &&
                  !alt.toLowerCase().includes('icon') &&
                  !alt.toLowerCase().includes('avatar') &&
                  !alt.toLowerCase().includes('badge') &&
                  !alt.toLowerCase().includes('banner') &&
                  !/^\\d+\$/.test(alt) &&
                  !seen.has(alt.toLowerCase())) {
                seen.add(alt.toLowerCase());
                books.push({ title: alt, author: null, percentComplete: 100 });
              }
            });
          }

          // Méthode 3 : Chercher dans les éléments scrollables (carousel)
          if (books.length < titleCount) {
            document.querySelectorAll('[class*="scroll"], [class*="carousel"], [class*="slider"], [class*="list"]').forEach(function(container) {
              container.querySelectorAll('img[alt]').forEach(function(img) {
                var alt = img.alt.trim();
                if (alt.length > 3 && alt.length < 200 &&
                    !alt.toLowerCase().includes('amazon') &&
                    !alt.toLowerCase().includes('logo') &&
                    !alt.toLowerCase().includes('icon') &&
                    !/^\\d+\$/.test(alt) &&
                    !seen.has(alt.toLowerCase())) {
                  // Vérifier que l'image a une taille typique de couverture
                  var w = img.naturalWidth || img.width;
                  var h = img.naturalHeight || img.height;
                  if ((w > 30 && h > 40) || (!w && !h)) {
                    seen.add(alt.toLowerCase());
                    books.push({ title: alt, author: null, percentComplete: 100 });
                  }
                }
              });
            });
          }
        }

        return JSON.stringify({ titleCount: titleCount, books: books, debug: 'found ' + books.length + '/' + titleCount });
      } catch(e) {
        return JSON.stringify({ titleCount: 0, books: [], error: e.message });
      }
    })();
  ''';

  /// Script synchrone pour scroller d'un viewport vers le bas
  /// Appelé en boucle depuis Dart pour le lazy loading
  static const String scrollStepScript = '''
    (function() {
      var before = window.scrollY;
      var viewportHeight = window.innerHeight;
      var maxScroll = document.body.scrollHeight - viewportHeight;
      var newPos = Math.min(before + viewportHeight, maxScroll);
      window.scrollTo(0, newPos);
      return JSON.stringify({
        scrollY: newPos,
        maxScroll: maxScroll,
        atBottom: newPos >= maxScroll - 10
      });
    })();
  ''';

  /// Script pour remonter en haut de page
  static const String scrollToTopScript = '''
    (function() { window.scrollTo(0, 0); return 'ok'; })();
  ''';

  /// Script pour cliquer sur "Show all" / "See all" boutons (sans naviguer)
  static const String expandAllBooksScript = '''
    (function() {
      var clicked = 0;
      // Ne cibler que les boutons et spans (pas les liens <a> qui navigueraient)
      var buttons = document.querySelectorAll('button, span, div[role="button"]');
      buttons.forEach(function(el) {
        var text = el.textContent.trim().toLowerCase();
        // Ne cliquer que sur les éléments courts (pas de gros blocs)
        if (text.length < 30 && (
            text === 'show all' || text === 'see all' ||
            text === 'view all' || text === 'voir tout' ||
            text === 'afficher tout' || text === 'show more' ||
            text === 'see more' || text === 'voir plus')) {
          el.click();
          clicked++;
        }
      });
      return JSON.stringify({ clicked: clicked });
    })();
  ''';

  /// Parse le résultat de l'extraction depuis Kindle Cloud Reader library
  List<KindleBookProgress> parseKindleLibraryResult(String? jsResult) {
    if (jsResult == null || jsResult.isEmpty) return [];
    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"');
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final booksList = json['books'] as List<dynamic>? ?? [];
      debugPrint('Kindle Library: ${booksList.length} livres extraits');
      return booksList.map((b) {
        final map = b as Map<String, dynamic>;
        return KindleBookProgress(
          title: map['title'] as String? ?? 'Unknown',
          author: map['author'] as String?,
          percentComplete: map['percentComplete'] as int?,
          coverUrl: map['coverUrl'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error parsing Kindle Library: $e');
      return [];
    }
  }

  /// Parse la liste des années depuis le résultat JS
  List<int> parseYearsList(String? jsResult) {
    if (jsResult == null || jsResult.isEmpty) return [];
    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"');
      }
      final list = jsonDecode(cleaned) as List<dynamic>;
      return list.map((e) => e as int).toList();
    } catch (e) {
      debugPrint('Error parsing years list: $e');
      return [];
    }
  }

  /// Parse le résultat de l'extraction des livres
  List<KindleBookProgress> parseBooksResult(String? jsResult, int year) {
    if (jsResult == null || jsResult.isEmpty) return [];
    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"');
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final booksList = json['books'] as List<dynamic>? ?? [];
      return booksList.map((b) {
        final map = b as Map<String, dynamic>;
        return KindleBookProgress(
          title: map['title'] as String? ?? 'Unknown',
          author: map['author'] as String?,
          percentComplete: map['percentComplete'] as int?,
          lastReadDate: '$year',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error parsing books for $year: $e');
      return [];
    }
  }

  /// Sauvegarde les données Kindle localement
  Future<void> saveLocally(KindleReadingData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Charge les données Kindle depuis le cache local
  Future<KindleReadingData?> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null) return null;
    try {
      return KindleReadingData.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  /// Récupère la date de dernière synchronisation
  Future<String?> getLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  /// Sauvegarde les données dans Supabase
  Future<void> saveToSupabase(KindleReadingData data) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('kindle_sync').upsert({
      'user_id': userId,
      'books_read_this_year': data.booksReadThisYear,
      'current_streak': data.currentStreak,
      'longest_streak': data.longestStreak,
      'total_days_read': data.totalDaysRead,
      'books_data': jsonEncode(data.books.map((b) => b.toJson()).toList()),
      'synced_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Parse le résultat du JavaScript d'extraction
  KindleReadingData? parseExtractionResult(String? jsResult) {
    if (jsResult == null || jsResult.isEmpty) return null;

    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"');
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        debugPrint('Kindle extraction error: ${json['error']}');
        return null;
      }

      return KindleReadingData.fromJson(json);
    } catch (e) {
      debugPrint('Error parsing Kindle data: $e');
      return null;
    }
  }
}

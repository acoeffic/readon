import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'kindle_background_sync.dart';

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

  /// Pourcentage lu (0-100) tel que rapporté par Amazon. `null` = inconnu :
  /// le scrape DOM de la bibliothèque ne le fournit jamais, seule l'API JSON
  /// `/kindle-library/search` (voir [fetchKindleLibraryJsonScript]) le donne.
  final int? percentComplete;
  final String? lastReadDate;
  final String? coverUrl;

  /// ASIN Amazon, connu uniquement via l'API JSON. Sert de clé stable pour
  /// `user_books.kindle_asin` (et à terme pour la résolution des surlignages).
  final String? asin;

  KindleBookProgress({
    required this.title,
    this.author,
    this.percentComplete,
    this.lastReadDate,
    this.coverUrl,
    this.asin,
  });

  factory KindleBookProgress.fromJson(Map<String, dynamic> json) {
    return KindleBookProgress(
      title: json['title'] as String? ?? 'Unknown',
      author: json['author'] as String?,
      percentComplete: (json['percentComplete'] as num?)?.toInt(),
      lastReadDate: json['lastReadDate'] as String?,
      coverUrl: json['coverUrl'] as String?,
      asin: json['asin'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'percentComplete': percentComplete,
        'lastReadDate': lastReadDate,
        'coverUrl': coverUrl,
        'asin': asin,
      };

  KindleBookProgress copyWith({int? percentComplete}) => KindleBookProgress(
        title: title,
        author: author,
        percentComplete: percentComplete ?? this.percentComplete,
        lastReadDate: lastReadDate,
        coverUrl: coverUrl,
        asin: asin,
      );
}

/// Calendrier de lecture Amazon (page Reading Insights).
class KindleInsightsCalendar {
  /// Jours (locaux, à minuit) où Amazon a enregistré de la lecture.
  final List<DateTime> daysRead;

  /// ASIN → date de fin de lecture selon Amazon (`titles_read`).
  final Map<String, DateTime> finishedAt;

  KindleInsightsCalendar({required this.daysRead, required this.finishedAt});

  /// Dernier jour lu dans la fenêtre ]after, upTo] (dates comparées au jour
  /// près). `null` si aucun.
  DateTime? lastReadDayBetween(DateTime? after, DateTime upTo) {
    final upToDay = DateTime(upTo.year, upTo.month, upTo.day);
    final afterDay = after == null
        ? null
        : DateTime(after.year, after.month, after.day);
    DateTime? best;
    for (final d in daysRead) {
      if (d.isAfter(upToDay)) continue;
      if (afterDay != null && !d.isAfter(afterDay)) continue;
      if (best == null || d.isAfter(best)) best = d;
    }
    return best;
  }
}

/// Position de lecture lue dans le Cloud Reader (`read.amazon.com/?asin=…`).
class KindleReaderProgress {
  final String asin;

  /// 0-100, calculé depuis la barre de progression (positions Kindle), en
  /// repli depuis le « 78% » du pied de page.
  final int percent;

  /// Numérotation de pages KINDLE (« Page 401 of 507 ») — pas celle de
  /// l'édition LexDay, à ne pas confondre.
  final int? kindlePage;
  final int? kindlePageCount;

  KindleReaderProgress({
    required this.asin,
    required this.percent,
    this.kindlePage,
    this.kindlePageCount,
  });
}

/// Un surlignage Kindle extrait de read.amazon.com/notebook.
class KindleHighlight {
  final String asin;
  final String bookTitle;
  final String? bookAuthor;
  final String text;
  final String? note;

  /// Numéro de page réel quand Amazon l'affiche dans l'entête du surlignage.
  /// Les « locations » Kindle ne sont PAS des pages : elles ne sont jamais
  /// mappées sur `page_number` (afficher « p. 3541 » serait mensonger).
  final int? page;

  /// Clé de déduplication : `kindle:<asin>:<id de ligne Amazon>` ou, à défaut,
  /// `kindle:<asin>:<location>:<hash du texte>`. Unique par utilisateur en DB
  /// (index `annotations_user_source_key_key`) → le re-crawl quotidien est
  /// idempotent.
  final String sourceKey;

  KindleHighlight({
    required this.asin,
    required this.bookTitle,
    this.bookAuthor,
    required this.text,
    this.note,
    this.page,
    required this.sourceKey,
  });

  factory KindleHighlight.fromJson(Map<String, dynamic> json) {
    return KindleHighlight(
      asin: json['asin'] as String? ?? '',
      bookTitle: json['bookTitle'] as String? ?? '',
      bookAuthor: json['bookAuthor'] as String?,
      text: json['text'] as String? ?? '',
      note: json['note'] as String?,
      page: json['page'] as int?,
      sourceKey: json['key'] as String? ?? '',
    );
  }
}

class KindleWebViewService {
  static const String _cacheKey = 'kindle_reading_data';
  static const String _lastSyncKey = 'kindle_last_sync';

  /// Titres promotionnels/par défaut fournis par Amazon dans toute bibliothèque
  /// Kindle. On les exclut de l'import pour qu'ils n'apparaissent jamais dans
  /// la bibliothèque LexDay. Comparaison insensible à la casse et aux accents.
  static const List<String> _ignoredBookTitles = [
    'explore what kindle can do',
    'welcome to kindle',
    'kindle user\'s guide',
    'kindle users guide',
    'the kindle user\'s guide',
    'guide d\'utilisation kindle',
    'guide de l\'utilisateur kindle',
    'bienvenue sur kindle',
  ];

  /// Renvoie true si le livre est un titre promotionnel Amazon à ignorer.
  static bool isIgnoredBook(String? title) {
    if (title == null) return false;
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final ignored in _ignoredBookTitles) {
      if (normalized == ignored || normalized.contains(ignored)) return true;
    }
    return false;
  }

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
  /// Calendrier de lecture Amazon, lu dans le JSON inline de la page
  /// Reading Insights (`preloadedData: {"days_read": ["2026-09-11", …],
  /// "goal_info": {"titles_read": [{asin, date_read, …}]}}`, vérifié en réel
  /// le 12/09/2026). Aucun rendu nécessaire : on lit `document.scripts`.
  /// Sert à dater les sessions Kindle au vrai jour de lecture.
  static const String extractInsightsPreloadedDataScript = '''
    (function() {
      try {
        var scripts = document.scripts;
        for (var i = 0; i < scripts.length; i++) {
          var t = scripts[i].textContent || '';
          var k = t.indexOf('"days_read"');
          if (k < 0) continue;
          var a = t.indexOf('[', k);
          var b = t.indexOf(']', a);
          if (a < 0 || b < 0) continue;
          var days = [];
          try { days = JSON.parse(t.slice(a, b + 1)); } catch (e) { continue; }
          days = days.filter(function(d) { return typeof d === 'string' && /^\\d{4}-\\d{2}-\\d{2}\$/.test(d); });
          var titles = [];
          var tr = t.indexOf('"titles_read"', b);
          if (tr >= 0) {
            var ta = t.indexOf('[', tr);
            var depth = 0, tb = -1;
            for (var j = ta; j < t.length && j < ta + 200000; j++) {
              var c = t[j];
              if (c === '[') depth++;
              else if (c === ']') { depth--; if (depth === 0) { tb = j; break; } }
            }
            if (ta >= 0 && tb > ta) {
              try {
                var arr = JSON.parse(t.slice(ta, tb + 1));
                titles = arr.map(function(x) { return { asin: x.asin || null, dateRead: x.date_read || null }; })
                            .filter(function(x) { return x.asin && x.dateRead; });
              } catch (e) {}
            }
          }
          return JSON.stringify({ found: true, daysRead: days.slice(-120), titlesRead: titles });
        }
        return JSON.stringify({ found: false });
      } catch(e) {
        return JSON.stringify({ found: false, error: e.message });
      }
    })();
  ''';

  /// Parse [extractInsightsPreloadedDataScript]. `null` si introuvable.
  KindleInsightsCalendar? parseInsightsPreloadedData(String? jsResult) {
    if (jsResult == null || jsResult.isEmpty) return null;
    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"');
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      if (json['found'] != true) return null;
      final days = <DateTime>[];
      for (final d in json['daysRead'] as List<dynamic>? ?? const []) {
        final parsed = DateTime.tryParse(d as String);
        if (parsed != null) days.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
      final finished = <String, DateTime>{};
      for (final t in json['titlesRead'] as List<dynamic>? ?? const []) {
        final m = t as Map<String, dynamic>;
        final dt = DateTime.tryParse(m['dateRead'] as String? ?? '');
        final asin = m['asin'] as String?;
        if (dt != null && asin != null) finished[asin] = dt.toLocal();
      }
      return KindleInsightsCalendar(daysRead: days, finishedAt: finished);
    } catch (e) {
      debugPrint('Error parsing insights preloaded data: $e');
      return null;
    }
  }

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

        // Pattern 3 : Extraire les livres TERMINÉS, en se limitant à la section
        // « N titles read ».
        //
        // Avant, on balayait TOUT le document (tout lien /dp/, /gp/product/ ou
        // /B0 portant une image) en forçant percentComplete: 100. Les tuiles
        // « en cours de lecture », les blocs promo et les carrousels de
        // recommandation passaient donc pour des livres terminés, et
        // markBooksAsFinished basculait en « finished » n'importe quel livre de
        // la bibliothèque de l'utilisateur qui apparaissait sur la page.
        //
        // Si la section est introuvable (locale non gérée, refonte Amazon), on
        // ne renvoie AUCUN livre plutôt que de corrompre des statuts : la
        // source de vérité du « terminé » reste percentComplete côté
        // bibliothèque (extractKindleLibraryScript).
        var seen = new Set();
        var titlesSection = null;
        // Volontairement peu ancrée : « Titles read in 2026 », « 12 livres lus
        // cette année »… doivent matcher. Le garde-fou est la longueur du
        // libellé (< 40 car.) et le plafond d'images plus bas.
        var sectionLabel = /(^|\\s)(\\d+\\s*)?(titles?\\s*read|(titres?|livres?)\\s*lus?)(\\s|\$)/i;
        var bestCount = Infinity;
        var candidates = document.querySelectorAll('span, div, p, h1, h2, h3, h4, strong, b, li');
        for (var k = 0; k < candidates.length; k++) {
          var candidate = candidates[k];
          if (candidate.children.length >= 5) continue;
          var label = (candidate.textContent || '').trim();
          if (label.length > 40) continue;
          if (!sectionLabel.test(label)) continue;

          // Remonter jusqu'au conteneur qui porte les couvertures — mais
          // seulement si le candidat n'en porte pas déjà, et sans jamais
          // atteindre la racine. Sans ces deux gardes on remontait jusqu'à
          // l'enfant direct de <body> (#a-page chez Amazon), donc toute la
          // page : le bug d'origine, reproduit à l'identique.
          var node = candidate;
          for (var j = 0; j < 6; j++) {
            if (node.querySelectorAll('img[alt]').length >= 2) break;
            var parent = node.parentElement;
            if (!parent || parent === document.body || parent === document.documentElement) break;
            node = parent;
          }
          // La section « titles read » est toujours imbriquée dans la page,
          // jamais le conteneur racine. Si la remontée a dû aller jusqu'à un
          // enfant direct de <body>, c'est qu'il n'y avait pas de vraie section
          // sous le libellé (item de menu, lien de nav) : on préfère ne rien
          // remonter plutôt que d'aspirer les blocs promo de la page.
          var nodeParent = node ? node.parentElement : null;
          if (!nodeParent || nodeParent === document.body || nodeParent === document.documentElement) continue;

          var imgCount = node.querySelectorAll('img[alt]').length;

          // Un conteneur qui porte beaucoup plus d'images que de livres lus
          // n'est pas la section : c'est un bloc de mise en page.
          //
          // Le compte vient du libellé lui-même (groupe 2 de la regex) en repli
          // de `booksReadThisYear` : Pattern 1 exige que le nombre et « titles
          // read » soient sur la MÊME ligne de innerText, ce qui n'est pas le
          // cas quand Amazon les rend dans deux blocs distincts. Sans ce repli,
          // le plafond restait à 30 et la section d'un lecteur à 40+ livres/an
          // était rejetée — la feature se désactivait d'autant plus que
          // l'utilisateur lit.
          var labelMatch = sectionLabel.exec(label);
          var labelCount = (labelMatch && labelMatch[2]) ? parseInt(labelMatch[2], 10) : 0;
          var expected = data.booksReadThisYear || labelCount;
          var maxImgs = expected > 0 ? Math.max(30, expected * 3) : 200;

          // On garde le conteneur le PLUS SERRÉ parmi tous les libellés qui
          // matchent : plusieurs ancêtres emboîtés peuvent matcher le même
          // texte, et le plus large engloberait les carrousels voisins.
          if (imgCount >= 1 && imgCount <= maxImgs && imgCount < bestCount) {
            titlesSection = node;
            bestCount = imgCount;
          }
        }

        data.booksScoped = titlesSection !== null;

        if (titlesSection) {
          var linkSelectors = 'a[href*="/dp/"], a[href*="/gp/product/"], a[href*="/B0"]';
          var links = titlesSection.querySelectorAll(linkSelectors);
          var pool = links.length > 0 ? links : titlesSection.querySelectorAll('img[alt]');
          pool.forEach(function(el) {
            var img = el.tagName === 'IMG' ? el : el.querySelector('img[alt]');
            if (!img) return;
            if (el.tagName === 'A') {
              var href = el.getAttribute('href') || '';
              if (href.includes('/help') || href.includes('/customer') || href.includes('/ref=nav')) return;
            }
            var alt = (img.alt || '').trim();
            var lower = alt.toLowerCase();
            if (alt.length <= 3 || alt.length >= 200) return;
            if (lower.includes('amazon') || lower.includes('logo') ||
                lower.includes('icon') || lower.includes('avatar') ||
                lower.includes('badge') || lower.includes('banner')) return;
            if (/^\\d+\$/.test(alt)) return;
            if (seen.has(lower)) return;
            seen.add(lower);
            data.books.push({ title: alt, author: null, percentComplete: 100 });
          });
        }

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

  /// Clique sur le bouton "Sign in" de la landing page Kindle pour déclencher
  /// la navigation vers le vrai form de signin Amazon (avec le bon assoc_handle
  /// géré côté Amazon). Renvoie true si un bouton a été cliqué.
  static const String clickSignInScript = '''
    (function() {
      try {
        var candidates = Array.prototype.slice.call(
          document.querySelectorAll('a, button')
        );
        for (var i = 0; i < candidates.length; i++) {
          var el = candidates[i];
          var href = (el.getAttribute('href') || '').toLowerCase();
          var txt = (el.innerText || el.textContent || '').trim().toLowerCase();
          var match = href.indexOf('/ap/signin') !== -1
              || /^sign[\\s-]?in\$/.test(txt)
              || /^se\\s+connecter\$/.test(txt);
          if (match) {
            if (el.tagName === 'A' && el.href) {
              window.location.href = el.href;
            } else {
              el.click();
            }
            return JSON.stringify({ clicked: true, txt: txt, href: href });
          }
        }
        return JSON.stringify({ clicked: false });
      } catch(e) {
        return JSON.stringify({ clicked: false, error: e.message });
      }
    })();
  ''';

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

  /// Position de lecture par simple GET du HTML du lecteur — SANS rendu.
  ///
  /// Vérifié en réel le 12/09/2026 : la page `read.amazon.com/?asin=X` est
  /// rendue côté serveur avec, dans un JSON inline (guillemets échappés en
  /// `\x22`), `mostRecentPositionRead`, `srl` (start reading location) et
  /// `endReadingPosition`. `(pos - srl) / (end - srl)` = exactement le % du
  /// lecteur (575269/737970 → 78 %). ~115 Ko par livre, ~1 s, aucun JS
  /// Amazon exécuté : c'est la voie par défaut, le rendu du lecteur
  /// ([readKindleReaderProgressScript]) n'est plus qu'un repli.
  ///
  /// Même contrat asynchrone que les autres crawlers : état dans
  /// `window.__lexdayRp`, poll via [checkKindleReaderHtmlScript], collecte via
  /// [collectKindleReaderHtmlScript]. Doit tourner depuis une page
  /// `read.amazon.com` (fetch same-origin avec cookies).
  static String fetchKindleReaderHtmlScript(List<String> asins) {
    final list = jsonEncode(asins);
    return '''
    (function() {
      try {
        if (window.__lexdayRp && window.__lexdayRp.running) return 'already-running';
        var S = { running: true, done: false, error: null, results: {}, failed: [] };
        window.__lexdayRp = S;
        var asins = $list;

        function num(t, key) {
          var m = t.match(new RegExp('"' + key + '":(-?\\\\d+)'));
          return m ? Number(m[1]) : null;
        }

        function parse(t) {
          // Les guillemets du JSON inline sont échappés en \\x22 dans le HTML.
          t = t.replace(/\\\\x22/g, '"');
          var pos = num(t, 'mostRecentPositionRead');
          var srl = num(t, 'srl');
          var end = num(t, 'endReadingPosition');
          if (end === null || end <= 0) return null;
          if (srl === null || srl < 0) srl = 0;
          if (pos === null) return { percent: null, pos: null, srl: srl, end: end };
          var span = end - srl;
          var pct = span > 0 ? Math.round((pos - srl) / span * 100) : 0;
          if (pct < 0) pct = 0;
          if (pct > 100) pct = 100;
          return { percent: pct, pos: pos, srl: srl, end: end };
        }

        function step(i) {
          if (i >= asins.length) { S.done = true; S.running = false; return; }
          var asin = asins[i];
          fetch('https://read.amazon.com/?asin=' + encodeURIComponent(asin), { credentials: 'include' })
            .then(function(r) {
              if (!r.ok) throw new Error('HTTP ' + r.status);
              if (r.url && r.url.indexOf('/ap/') !== -1) throw new Error('signin');
              return r.text();
            })
            .then(function(t) {
              var p = parse(t);
              if (p) S.results[asin] = p; else S.failed.push(asin);
              step(i + 1);
            })
            .catch(function(e) {
              S.failed.push(asin);
              if (!S.error) S.error = (e && e.message) ? e.message : String(e);
              step(i + 1);
            });
        }
        step(0);
        return 'started';
      } catch(e) {
        if (window.__lexdayRp) { window.__lexdayRp.done = true; window.__lexdayRp.running = false; window.__lexdayRp.error = e.message; }
        return 'error: ' + e.message;
      }
    })();
  ''';
  }

  static const String checkKindleReaderHtmlScript = '''
    (function() {
      var S = window.__lexdayRp;
      if (!S) return JSON.stringify({ exists: false });
      return JSON.stringify({ exists: true, done: !!S.done, count: Object.keys(S.results).length, failed: S.failed.length, error: S.error || null });
    })();
  ''';

  static const String collectKindleReaderHtmlScript = '''
    (function() {
      var S = window.__lexdayRp;
      if (!S) return '';
      return encodeURIComponent(JSON.stringify({ results: S.results, failed: S.failed, error: S.error || null }));
    })();
  ''';

  /// Récupère la progression de [asins] par GET HTML (voir
  /// [fetchKindleReaderHtmlScript]). Renvoie une map ASIN → progression pour
  /// les livres résolus (un livre jamais ouvert a `percent == null` et n'est
  /// pas inclus). Vide si rien n'a pu être lu.
  Future<Map<String, KindleReaderProgress>> fetchReaderProgressViaHtml(
    WebViewController controller,
    List<String> asins, {
    Duration timeout = const Duration(seconds: 40),
    bool Function()? shouldAbort,
  }) async {
    if (asins.isEmpty) return {};
    final deadline = DateTime.now().add(timeout);
    try {
      final started = await controller.runJavaScriptReturningResult(
        fetchKindleReaderHtmlScript(asins),
      );
      debugPrint('Kindle progression HTML: start = $started (${asins.length} livres)');
      var done = false;
      while (DateTime.now().isBefore(deadline)) {
        if (shouldAbort?.call() ?? false) return {};
        await Future.delayed(const Duration(milliseconds: 500));
        final st = (await controller.runJavaScriptReturningResult(
          checkKindleReaderHtmlScript,
        ))
            .toString();
        if (st.contains('"done":true')) {
          done = true;
          break;
        }
        if (st.contains('"exists":false')) break;
      }
      if (!done) debugPrint('Kindle progression HTML: échéance atteinte, résultat partiel');

      var raw = (await controller.runJavaScriptReturningResult(
        collectKindleReaderHtmlScript,
      ))
          .toString();
      if (raw.startsWith('"') && raw.endsWith('"')) {
        raw = raw.substring(1, raw.length - 1);
      }
      if (raw.isEmpty || raw == 'null') return {};
      final json = jsonDecode(Uri.decodeComponent(raw)) as Map<String, dynamic>;
      if (json['error'] != null) {
        debugPrint('Kindle progression HTML: erreur ${json['error']} (échecs: ${json['failed']})');
      }
      final results = json['results'] as Map<String, dynamic>? ?? {};
      final out = <String, KindleReaderProgress>{};
      results.forEach((asin, v) {
        final m = v as Map<String, dynamic>;
        final pct = (m['percent'] as num?)?.toInt();
        if (pct == null) return;
        out[asin] = KindleReaderProgress(asin: asin, percent: pct);
      });
      return out;
    } catch (e) {
      debugPrint('Kindle progression HTML: erreur $e');
      return {};
    }
  }

  /// Lecture de la position courante dans le Cloud Reader.
  ///
  /// Vérifié en réel le 10/09/2026 : `/kindle-library/search` expose bien
  /// `percentageRead`, mais Amazon le laisse à 0 sur TOUS les livres (50/50
  /// sur le compte d'Adrien, y compris un livre à 78 %). La seule source de
  /// progression fiable est le lecteur web lui-même, qui affiche en pied de
  /// page « Page 401 of 507 ● 78% » (`ion-title.footer-label.position`) et
  /// porte une barre `ion-range#kr-scrubber-bar` dont value/max est le ratio
  /// de positions Kindle. Le lecteur est une app Ionic : les nœuds sont dans
  /// le DOM léger, pas dans un shadow root.
  ///
  /// Renvoie `{ready:false}` tant que le pied de page n'est pas rendu.
  /// L'`asin` est relu depuis l'URL pour que Dart ignore la valeur d'un
  /// lecteur précédent encore affiché pendant la navigation vers le suivant.
  static const String readKindleReaderProgressScript = '''
    (function() {
      try {
        var asin = null;
        try { asin = new URLSearchParams(location.search).get('asin'); } catch(e) {}
        var pos = document.querySelector('ion-title.footer-label.position');
        var text = pos ? (pos.textContent || '').trim() : '';
        var range = document.querySelector('ion-range#kr-scrubber-bar');
        var rv = null, rm = null;
        if (range) {
          rv = Number(range.value);
          rm = Number(range.max);
          if (!isFinite(rv) || !isFinite(rm)) { rv = null; rm = null; }
        }
        var pctText = null;
        var m = text.match(/(\\d{1,3})\\s*%/);
        if (m) pctText = parseInt(m[1], 10);
        var page = null, total = null;
        var pm = text.match(/(\\d+)\\D+(\\d+)/);
        if (pm) { page = parseInt(pm[1], 10); total = parseInt(pm[2], 10); }
        var ready = (rv !== null && rm !== null && rm > 0) || pctText !== null;
        return JSON.stringify({
          ready: ready,
          asin: asin,
          text: text,
          rangeValue: rv,
          rangeMax: rm,
          percentText: pctText,
          page: page,
          total: total
        });
      } catch(e) {
        return JSON.stringify({ ready: false, error: e.message });
      }
    })();
  ''';

  /// Diagnostic quand le pied de page du lecteur n'apparaît pas : de quoi
  /// distinguer « page pas chargée », « redirigé », « viewport nul » ou
  /// « app chargée mais pied de page absent ».
  static const String readerDiagnosticScript = '''
    (function() {
      try {
        var t = (document.body && document.body.innerText || '').replace(/\\s+/g, ' ').slice(0, 200);
        return JSON.stringify({
          url: location.href,
          readyState: document.readyState,
          visibility: document.visibilityState,
          w: window.innerWidth, h: window.innerHeight,
          ionApp: !!document.querySelector('ion-app'),
          footerLabels: document.querySelectorAll('ion-title.footer-label').length,
          range: !!document.querySelector('ion-range'),
          text: t
        });
      } catch(e) {
        return JSON.stringify({ error: e.message });
      }
    })();
  ''';

  /// Parse [readKindleReaderProgressScript]. `null` tant que ce n'est pas
  /// prêt, ou si l'ASIN de la page ne correspond pas à [expectedAsin].
  KindleReaderProgress? parseReaderProgress(
    String? jsResult, {
    required String expectedAsin,
  }) {
    if (jsResult == null || jsResult.isEmpty) return null;
    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"');
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      if (json['ready'] != true) return null;
      if (json['asin'] != expectedAsin) return null;

      final rv = (json['rangeValue'] as num?)?.toDouble();
      final rm = (json['rangeMax'] as num?)?.toDouble();
      int? percent;
      if (rv != null && rm != null && rm > 0) {
        percent = (rv / rm * 100).round();
      }
      percent ??= (json['percentText'] as num?)?.toInt();
      if (percent == null) return null;
      percent = percent.clamp(0, 100).toInt();

      return KindleReaderProgress(
        asin: expectedAsin,
        percent: percent,
        kindlePage: (json['page'] as num?)?.toInt(),
        kindlePageCount: (json['total'] as num?)?.toInt(),
      );
    } catch (e) {
      debugPrint('Error parsing reader progress: $e');
      return null;
    }
  }

  /// Récupération de la bibliothèque via l'API JSON interne du Cloud Reader.
  ///
  /// `read.amazon.com/kindle-library/search` est l'endpoint que la page
  /// appelle elle-même pour afficher les tuiles. Contrairement au DOM, il
  /// porte l'ASIN et le pourcentage lu de chaque livre — c'est la SEULE source
  /// de progression connue ; la page n'affiche aucune barre exploitable
  /// (`debugKindleLibraryScript` n'a jamais rien trouvé).
  ///
  /// Asynchrone (fetch + pagination) : iOS ne sait pas attendre une Promise
  /// depuis `runJavaScriptReturningResult`, donc l'état s'accumule dans
  /// `window.__lexdayLib` et Dart polle [checkKindleLibraryJsonScript] puis
  /// lit [collectKindleLibraryJsonScript]. Même pattern que le crawler des
  /// surlignages.
  ///
  /// Robustesse : les noms de champs Amazon ne sont pas documentés. On lit
  /// `percentageRead` en priorité avec quelques alias, et on conserve les clés
  /// du premier item brut (`sampleKeys`) pour les logs — c'est ce qui permet
  /// de corriger le mapping au premier test réel si le nom diffère.
  static const String fetchKindleLibraryJsonScript = '''
    (function() {
      try {
        if (window.__lexdayLib && window.__lexdayLib.running) return 'already-running';
        var S = {
          running: true,
          done: false,
          error: null,
          books: [],
          pages: 0,
          sampleKeys: null,
          sampleItem: null
        };
        window.__lexdayLib = S;

        var MAX_PAGES = 40;
        var QUERY_SIZE = 50;

        function pickPercent(item) {
          var keys = ['percentageRead', 'percentRead', 'percentComplete',
                      'percentageComplete', 'readingProgress', 'progress'];
          for (var i = 0; i < keys.length; i++) {
            var v = item[keys[i]];
            if (typeof v === 'number' && isFinite(v)) return v;
            if (typeof v === 'string' && v !== '' && isFinite(Number(v))) return Number(v);
            if (v && typeof v === 'object') {
              var inner = pickPercent(v);
              if (inner !== null) return inner;
            }
          }
          return null;
        }

        function cleanAuthor(a) {
          if (!a) return null;
          if (Array.isArray(a)) a = a.filter(function(x) { return !!x; }).join(', ');
          a = String(a).replace(/:\\s*/g, ', ').replace(/,\\s*,/g, ',').replace(/^[,\\s]+|[,\\s]+\$/g, '');
          return a.length > 0 ? a : null;
        }

        function mapItem(item) {
          var title = item.title || item.name || null;
          if (!title) return null;
          var pct = pickPercent(item);
          if (pct !== null) {
            // Ratio 0-1 (strict : un vrai « 1 % » ne doit pas devenir 100 %).
            if (pct > 0 && pct < 1) pct = pct * 100;
            pct = Math.round(pct);
            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;
          }
          var cover = item.productUrl || item.coverUrl || item.imageUrl || null;
          return {
            title: String(title).trim(),
            author: cleanAuthor(item.authors || item.author),
            percentComplete: pct,
            coverUrl: cover,
            asin: item.asin || null
          };
        }

        function fetchPage(token) {
          var url = 'https://read.amazon.com/kindle-library/search?query=&libraryType=BOOKS'
                  + '&sortType=recency&querySize=' + QUERY_SIZE
                  + (token ? '&paginationToken=' + encodeURIComponent(token) : '');
          return fetch(url, { credentials: 'include', headers: { 'Accept': 'application/json' } })
            .then(function(r) {
              if (!r.ok) throw new Error('HTTP ' + r.status);
              return r.json();
            });
        }

        function step(token) {
          if (S.pages >= MAX_PAGES) { S.done = true; S.running = false; return; }
          fetchPage(token).then(function(json) {
            S.pages++;
            var items = json.itemsList || json.items || json.books || [];
            if (!S.sampleKeys && items.length > 0) {
              S.sampleKeys = Object.keys(items[0]);
              var sample = {};
              S.sampleKeys.forEach(function(k) {
                var v = items[0][k];
                if (typeof v === 'string' && v.length > 80) v = v.slice(0, 80) + '…';
                sample[k] = v;
              });
              S.sampleItem = sample;
            }
            for (var i = 0; i < items.length; i++) {
              var b = mapItem(items[i]);
              if (b) S.books.push(b);
            }
            var next = json.paginationToken || null;
            if (next && items.length > 0 && String(next) !== String(token || '')) {
              step(next);
            } else {
              S.done = true; S.running = false;
            }
          }).catch(function(e) {
            S.error = e && e.message ? e.message : String(e);
            S.done = true; S.running = false;
          });
        }

        step(null);
        return 'started';
      } catch(e) {
        if (window.__lexdayLib) {
          window.__lexdayLib.done = true;
          window.__lexdayLib.running = false;
          window.__lexdayLib.error = e.message;
        }
        return 'error: ' + e.message;
      }
    })();
  ''';

  /// État du fetch JSON : `{exists, done, count, error}`.
  static const String checkKindleLibraryJsonScript = '''
    (function() {
      var S = window.__lexdayLib;
      if (!S) return JSON.stringify({ exists: false });
      return JSON.stringify({
        exists: true,
        done: !!S.done,
        count: S.books.length,
        pages: S.pages,
        error: S.error || null
      });
    })();
  ''';

  /// Résultat complet du fetch JSON, encodé (`encodeURIComponent`) pour
  /// traverser sans dommage le pont WebView → Dart (guillemets, accents).
  static const String collectKindleLibraryJsonScript = '''
    (function() {
      var S = window.__lexdayLib;
      if (!S) return '';
      return encodeURIComponent(JSON.stringify({
        books: S.books,
        count: S.books.length,
        pages: S.pages,
        error: S.error || null,
        sampleKeys: S.sampleKeys,
        sampleItem: S.sampleItem
      }));
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

          // Ignorer les images promotionnelles (bannières app store, badges, etc.)
          var imgAlt = (img.getAttribute('alt') || '').toLowerCase();
          if (imgAlt.includes('download') || imgAlt.includes('app store') ||
              imgAlt.includes('google play') || imgAlt.includes('windows') ||
              imgAlt.includes('get it on') || imgAlt.includes('available on') ||
              imgAlt.includes('badge') || imgAlt.includes('banner') ||
              imgAlt.includes('promotion') || imgAlt.includes('advertisement') ||
              imgAlt.includes('install') || imgAlt.includes('platform')) return;

          // Ignorer les images au format paysage (bannières) — les couvertures sont en portrait
          if (rect.width > rect.height * 1.2) return;

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

  /// Lance le crawl ASYNCHRONE des surlignages sur read.amazon.com/notebook.
  ///
  /// iOS ne supporte pas d'attendre une Promise depuis
  /// `runJavaScriptReturningResult` : ce script démarre donc le crawl et rend
  /// la main immédiatement, l'état s'accumule dans `window.__lexdayHl` que
  /// Dart interroge en boucle via [checkNotebookCrawlScript] puis récupère par
  /// tranches via [collectNotebookChunkScript].
  ///
  /// Le crawl réutilise l'endpoint AJAX de la page elle-même :
  /// `/notebook?asin=<ASIN>&contentLimitState=<state>&token=<token>` renvoie le
  /// fragment HTML des surlignages d'un livre, paginé par un token porté par
  /// l'input caché `.kp-notebook-annotations-next-page-start` (même mécanique
  /// que les scrapers type Readwise). Les fetch partent de la page authentifiée
  /// → mêmes cookies, même origine.
  ///
  /// Un livre qui échoue (fragment illisible, HTTP != 200) est simplement
  /// sauté : la dédup par `key` rend le crawl re-jouable au sync suivant.
  static const String startNotebookCrawlScript = '''
    (function() {
      try {
        if (window.__lexdayHl && window.__lexdayHl.running) return 'already-running';

        var S = {
          running: true,
          done: false,
          error: null,
          booksTotal: 0,
          booksDone: 0,
          highlights: []
        };
        window.__lexdayHl = S;

        var MAX_HIGHLIGHTS = 2000;
        var MAX_BOOKS = 100;
        var MAX_PAGES_PER_BOOK = 60;

        var seen = new Set();

        function hashText(str) {
          var h = 0;
          for (var i = 0; i < str.length; i++) {
            h = ((h << 5) - h + str.charCodeAt(i)) | 0;
          }
          return (h >>> 0).toString(36);
        }

        function bookList() {
          var out = [];
          var els = document.querySelectorAll(
            '#kp-notebook-library .kp-notebook-library-each-book'
          );
          els.forEach(function(el) {
            var asin = el.getAttribute('id') || '';
            // Un ASIN est un identifiant alphanumérique de 10 caractères.
            if (!/^[A-Z0-9]{10}\$/i.test(asin)) return;
            // Crawl incrémental : Dart peut poser `window.__lexdayHlOnly`
            // (liste d'ASIN) pour ne recrawler que les livres qui ont bougé.
            var only = window.__lexdayHlOnly;
            if (only && only.length && only.indexOf(asin) < 0) return;
            var titleEl = el.querySelector('h2');
            var img = el.querySelector('img[alt]');
            var title = titleEl ? titleEl.textContent.trim()
                                : (img ? (img.alt || '').trim() : '');
            if (!title) return;
            var authorEl = el.querySelector('p');
            var author = authorEl
              ? authorEl.textContent.trim().replace(/^(by|par|de|por)\\s*:?\\s*/i, '')
              : null;
            out.push({ asin: asin, title: title, author: author });
          });
          return out;
        }

        function parseFragment(html, book) {
          var doc = new DOMParser().parseFromString(html, 'text/html');

          doc.querySelectorAll('#highlight').forEach(function(hlEl) {
            if (S.highlights.length >= MAX_HIGHLIGHTS) return;
            var text = (hlEl.textContent || '').trim();
            if (text.length < 2 || text.length > 5000) return;

            // La ligne d'annotation : porte l'id Amazon, la note et la location.
            var row = hlEl.closest('.a-row') || hlEl.parentElement;

            var note = null;
            var location = null;
            var page = null;
            var rowId = '';
            if (row) {
              rowId = (row.getAttribute('id') || '').trim();
              var noteEl = row.querySelector('#note');
              if (noteEl) {
                var n = (noteEl.textContent || '').trim();
                if (n.length > 0 && n.length < 5000) note = n;
              }
              var locEl = row.querySelector('#kp-annotation-location');
              if (locEl && locEl.value) {
                var loc = parseInt(locEl.value, 10);
                if (!isNaN(loc)) location = loc;
              }
              var header = row.querySelector('#annotationHighlightHeader');
              if (header) {
                // « Page: 42 » / « Page : 42 » — uniquement une vraie page,
                // jamais la location (qui n'est pas une page).
                var pm = (header.textContent || '').match(/page[^0-9]{0,3}([0-9]+)/i);
                if (pm) page = parseInt(pm[1], 10);
              }
            }

            var key = rowId.length >= 8
              ? 'kindle:' + book.asin + ':' + rowId
              : 'kindle:' + book.asin + ':' + (location === null ? 'x' : location) +
                ':' + hashText(text);
            if (seen.has(key)) return;
            seen.add(key);

            S.highlights.push({
              asin: book.asin,
              bookTitle: book.title,
              bookAuthor: book.author,
              text: text,
              note: note,
              page: page,
              key: key
            });
          });

          var tokenEl = doc.querySelector('.kp-notebook-annotations-next-page-start');
          var limitEl = doc.querySelector('.kp-notebook-content-limit-state');
          var token = tokenEl && tokenEl.value ? tokenEl.value : null;
          var limit = limitEl && limitEl.value ? limitEl.value : '';
          return { token: token, limit: limit };
        }

        function crawlBook(book, token, limit, pageNum) {
          if (pageNum >= MAX_PAGES_PER_BOOK) return Promise.resolve();
          if (S.highlights.length >= MAX_HIGHLIGHTS) return Promise.resolve();
          var url = 'https://read.amazon.com/notebook?asin=' +
            encodeURIComponent(book.asin) +
            '&contentLimitState=' + encodeURIComponent(limit || '') +
            (token ? '&token=' + encodeURIComponent(token) : '');
          return fetch(url, {
            credentials: 'include',
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
          }).then(function(r) {
            if (!r.ok) throw new Error('http ' + r.status);
            return r.text();
          }).then(function(html) {
            var next = parseFragment(html, book);
            if (next.token) return crawlBook(book, next.token, next.limit, pageNum + 1);
          });
        }

        var books = bookList().slice(0, MAX_BOOKS);
        S.booksTotal = books.length;

        var bi = 0;
        function nextBook() {
          if (bi >= books.length || S.highlights.length >= MAX_HIGHLIGHTS) {
            S.done = true;
            S.running = false;
            return;
          }
          var book = books[bi];
          bi++;
          crawlBook(book, null, '', 0)
            .catch(function(e) { S.error = String(e && e.message || e); })
            .then(function() { S.booksDone = bi; nextBook(); });
        }
        nextBook();

        return JSON.stringify({ started: true, booksTotal: S.booksTotal });
      } catch(e) {
        if (window.__lexdayHl) {
          window.__lexdayHl.done = true;
          window.__lexdayHl.running = false;
          window.__lexdayHl.error = e.message;
        }
        return JSON.stringify({ started: false, error: e.message });
      }
    })();
  ''';

  /// Script SYNCHRONE de poll de l'état du crawl notebook (appelé en boucle
  /// depuis Dart, comme [checkLibraryLoadedScript]).
  static const String checkNotebookCrawlScript = '''
    (function() {
      try {
        var S = window.__lexdayHl;
        if (!S) return JSON.stringify({ exists: false });
        return JSON.stringify({
          exists: true,
          done: S.done === true,
          count: S.highlights.length,
          booksDone: S.booksDone,
          booksTotal: S.booksTotal,
          error: S.error
        });
      } catch(e) {
        return JSON.stringify({ exists: false, error: e.message });
      }
    })();
  ''';

  /// Récupère une tranche des surlignages accumulés par le crawl.
  ///
  /// Le payload est passé par `encodeURIComponent` : le texte des surlignages
  /// contient guillemets et retours à la ligne, et le double encodage
  /// plateforme (iOS renvoie la chaîne brute, Android une chaîne JSON-encodée)
  /// rendait le nettoyage par `replaceAll(r'\\"', '"')` non fiable sur des
  /// gros contenus. Encodé en pourcent, le résultat ne contient ni quote ni
  /// backslash — voir [parseNotebookChunk].
  static String collectNotebookChunkScript(int start, int count) {
    return '''
      (function() {
        try {
          var S = window.__lexdayHl;
          if (!S) return encodeURIComponent('[]');
          return encodeURIComponent(
            JSON.stringify(S.highlights.slice($start, ${start + count}))
          );
        } catch(e) {
          return encodeURIComponent('[]');
        }
      })();
    ''';
  }

  /// Pose (ou lève, avec `null`) le filtre d'ASIN du crawl notebook — à
  /// exécuter AVANT [startNotebookCrawlScript].
  static String setNotebookCrawlFilterScript(List<String>? asins) {
    final value = asins == null ? 'null' : jsonEncode(asins);
    return 'window.__lexdayHlOnly = $value; "ok";';
  }

  /// Parse une tranche de surlignages renvoyée par [collectNotebookChunkScript].
  List<KindleHighlight> parseNotebookChunk(String? jsResult) {
    if (jsResult == null || jsResult.isEmpty) return [];
    try {
      String cleaned = jsResult.trim();
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
      final decoded = Uri.decodeComponent(cleaned);
      final list = jsonDecode(decoded) as List<dynamic>;
      return list
          .map((e) => KindleHighlight.fromJson(e as Map<String, dynamic>))
          .where((h) =>
              h.text.isNotEmpty &&
              h.sourceKey.isNotEmpty &&
              h.bookTitle.isNotEmpty &&
              !isIgnoredBook(h.bookTitle))
          .toList();
    } catch (e) {
      debugPrint('Error parsing notebook chunk: $e');
      return [];
    }
  }

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
      return booksList
          .map((b) {
            final map = b as Map<String, dynamic>;
            return KindleBookProgress(
              title: map['title'] as String? ?? 'Unknown',
              author: map['author'] as String?,
              percentComplete: (map['percentComplete'] as num?)?.toInt(),
              coverUrl: map['coverUrl'] as String?,
              asin: map['asin'] as String?,
            );
          })
          .where((b) => !isIgnoredBook(b.title))
          .toList();
    } catch (e) {
      debugPrint('Error parsing Kindle Library: $e');
      return [];
    }
  }

  /// Lance le fetch JSON de la bibliothèque dans [controller] et attend son
  /// résultat (au plus [timeout]). Renvoie une liste vide en cas d'échec ou
  /// d'abandon ([shouldAbort]) : l'appelant retombe sur le scrape DOM.
  ///
  /// Pré-requis : la page `read.amazon.com` (n'importe laquelle) est chargée,
  /// pour que le fetch soit same-origin et porte les cookies de session.
  Future<List<KindleBookProgress>> fetchLibraryViaJson(
    WebViewController controller, {
    Duration timeout = const Duration(seconds: 25),
    bool Function()? shouldAbort,
  }) async {
    final deadline = DateTime.now().add(timeout);
    try {
      final started = await controller.runJavaScriptReturningResult(
        fetchKindleLibraryJsonScript,
      );
      debugPrint('Kindle Library JSON: start = $started');

      var done = false;
      while (DateTime.now().isBefore(deadline)) {
        if (shouldAbort?.call() ?? false) return [];
        await Future.delayed(const Duration(milliseconds: 400));
        final status = await controller.runJavaScriptReturningResult(
          checkKindleLibraryJsonScript,
        );
        final st = status.toString();
        if (st.contains('"done":true')) {
          done = true;
          break;
        }
        if (st.contains('"exists":false')) break;
      }
      if (!done) {
        debugPrint('Kindle Library JSON: pas terminé avant l\'échéance');
      }
      if (shouldAbort?.call() ?? false) return [];

      final raw = await controller.runJavaScriptReturningResult(
        collectKindleLibraryJsonScript,
      );
      return parseKindleLibraryJsonResult(raw.toString());
    } catch (e) {
      debugPrint('Kindle Library JSON: erreur $e');
      return [];
    }
  }

  /// Parse le résultat de [collectKindleLibraryJsonScript].
  ///
  /// Renvoie une liste vide si l'API n'a rien donné (erreur HTTP, format
  /// inattendu) — l'appelant retombe alors sur le scrape DOM. Si AUCUN livre ne
  /// porte de pourcentage > 0, les pourcentages sont remis à `null` : un 0
  /// généralisé signifie qu'Amazon ne renseigne pas le champ (ou que le nom du
  /// champ a changé), pas que l'utilisateur n'a rien lu. Les clés reçues sont
  /// loguées pour corriger le mapping au premier test réel.
  List<KindleBookProgress> parseKindleLibraryJsonResult(String? jsResult) {
    if (jsResult == null || jsResult.isEmpty) return [];
    try {
      String cleaned = jsResult;
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
      if (cleaned.isEmpty || cleaned == 'null') return [];
      final decoded = Uri.decodeComponent(cleaned);
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      final error = json['error'];
      final sampleKeys = json['sampleKeys'];
      debugPrint(
        'Kindle Library JSON: ${json['count']} livres, ${json['pages']} page(s)'
        '${error != null ? ', erreur: $error' : ''}',
      );
      if (sampleKeys != null) {
        debugPrint('Kindle Library JSON: clés reçues = $sampleKeys');
        debugPrint('Kindle Library JSON: premier item = ${json['sampleItem']}');
      }

      final booksList = json['books'] as List<dynamic>? ?? [];
      var books = booksList
          .map((b) {
            final map = b as Map<String, dynamic>;
            return KindleBookProgress(
              title: map['title'] as String? ?? 'Unknown',
              author: map['author'] as String?,
              percentComplete: (map['percentComplete'] as num?)?.toInt(),
              coverUrl: map['coverUrl'] as String?,
              asin: map['asin'] as String?,
            );
          })
          .where((b) => b.title != 'Unknown' && !isIgnoredBook(b.title))
          .toList();

      final hasAnyProgress =
          books.any((b) => (b.percentComplete ?? 0) > 0);
      if (!hasAnyProgress) {
        // Cas nominal (vérifié le 10/09/2026) : Amazon renvoie 0 partout.
        // La progression réelle vient de la phase « lecteur » du widget
        // (readKindleReaderProgressScript), pas de cette API.
        debugPrint(
          'Kindle Library JSON: aucun pourcentage > 0 (attendu) — '
          'progression déléguée au lecteur',
        );
        books = books
            .map((b) => KindleBookProgress(
                  title: b.title,
                  author: b.author,
                  percentComplete: null,
                  coverUrl: b.coverUrl,
                  asin: b.asin,
                ))
            .toList();
      }
      return books;
    } catch (e) {
      debugPrint('Error parsing Kindle Library JSON: $e');
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
      return booksList
          .map((b) {
            final map = b as Map<String, dynamic>;
            return KindleBookProgress(
              title: map['title'] as String? ?? 'Unknown',
              author: map['author'] as String?,
              percentComplete: map['percentComplete'] as int?,
              lastReadDate: '$year',
            );
          })
          .where((b) => !isIgnoredBook(b.title))
          .toList();
    } catch (e) {
      debugPrint('Error parsing books for $year: $e');
      return [];
    }
  }

  /// Sauvegarde les données Kindle localement et marque le sync comme RÉUSSI.
  ///
  /// À n'appeler qu'en fin de pipeline, avec des données complètes : poser
  /// `kindle_last_sync` verrouille l'auto-sync pour 24 h (voir
  /// `KindleAutoSyncService.shouldAutoSync`). Pour mettre en cache un résultat
  /// intermédiaire, utiliser `cacheBooksOnly()`.
  Future<void> saveLocally(KindleReadingData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    // Sync réussi → la session Amazon est valide : reset du flag
    // « expiration notifiée » (voir KindleAutoSyncService).
    await prefs.remove('kindle_expired_notified');
    await prefs.remove('kindle_expired_notified_at');
  }

  /// Met en cache la seule liste de livres, en préservant les streaks déjà
  /// connues, SANS marquer le sync comme réussi.
  ///
  /// Utilisé au milieu du pipeline d'auto-sync : à ce stade les streaks ne sont
  /// pas encore extraites. Passer par `saveLocally()` ici écrasait le cache
  /// avec des streaks nulles *et* posait `kindle_last_sync`, ce qui rendormait
  /// l'auto-sync 24 h sur des données incomplètes.
  Future<void> cacheBooksOnly(List<KindleBookProgress> books) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadFromCache();
    final merged = KindleReadingData(
      booksReadThisYear: existing?.booksReadThisYear,
      currentStreak: existing?.currentStreak,
      weeksStreak: existing?.weeksStreak,
      daysStreak: existing?.daysStreak,
      longestStreak: existing?.longestStreak,
      totalDaysRead: existing?.totalDaysRead,
      totalMinutesRead: existing?.totalMinutesRead,
      lastSyncDate: existing?.lastSyncDate,
      books: books,
    );
    await prefs.setString(_cacheKey, jsonEncode(merged.toJson()));
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

  /// Déconnecte le compte Kindle : vide le cache local, les cookies WebView et
  /// supprime la ligne `kindle_sync` en Supabase. Les livres déjà importés
  /// dans la bibliothèque LexDay sont conservés (un disconnect ≠ un wipe books).
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove('kindle_expired_notified');
    await prefs.remove('kindle_expired_notified_at');
    // Sinon une reconnexion héritait du backoff de la session précédente.
    await prefs.remove('kindle_last_attempt');
    await prefs.remove('kindle_failed_attempts');
    await prefs.remove('kindle_highlights_pending');
    await prefs.remove('kindle_last_progress_sync');

    // Plus de tâche d'arrière-plan ni de cookies en cache.
    await KindleBackgroundSync.cancel();

    try {
      await WebViewCookieManager().clearCookies();
    } catch (e) {
      debugPrint('Kindle disconnect: clearCookies failed: $e');
    }

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        // `.select()` sur le delete : sans ça, un DELETE bloqué par la RLS
        // renvoie 204 sans erreur et l'app confirmait une déconnexion qui
        // n'avait rien supprimé (la table n'avait aucune policy DELETE).
        final deleted = await supabase
            .from('kindle_sync')
            .delete()
            .eq('user_id', userId)
            .select('user_id');
        if ((deleted as List).isEmpty) {
          debugPrint(
            'Kindle disconnect: aucune ligne kindle_sync supprimée '
            '(policy DELETE manquante ?)',
          );
        }
      }
    } catch (e) {
      debugPrint('Kindle disconnect: Supabase delete failed: $e');
    }
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

      // `booksScoped: false` = la section « N titles read » est introuvable
      // (locale non gérée, refonte de la page). On préfère ne marquer aucun
      // livre terminé plutôt que d'en marquer au hasard, mais il faut pouvoir
      // distinguer ce cas de « section vide ».
      if (json['booksScoped'] == false) {
        debugPrint(
          'Kindle insights: section « titles read » introuvable — '
          'aucun livre marqué terminé depuis cette page',
        );
      }

      final data = KindleReadingData.fromJson(json);
      // Exclure les titres promotionnels Amazon des livres remontés par insights.
      final filteredBooks =
          data.books.where((b) => !isIgnoredBook(b.title)).toList();
      return KindleReadingData(
        booksReadThisYear: data.booksReadThisYear,
        currentStreak: data.currentStreak,
        weeksStreak: data.weeksStreak,
        daysStreak: data.daysStreak,
        longestStreak: data.longestStreak,
        totalDaysRead: data.totalDaysRead,
        totalMinutesRead: data.totalMinutesRead,
        lastSyncDate: data.lastSyncDate,
        books: filteredBooks,
      );
    } catch (e) {
      debugPrint('Error parsing Kindle data: $e');
      return null;
    }
  }
}

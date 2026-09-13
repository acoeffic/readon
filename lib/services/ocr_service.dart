// lib/services/ocr_service.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/image_ops.dart';

/// Ligne de texte OCR avec la hauteur de sa bounding box (≈ taille de police).
/// Permet de classer les lignes par importance visuelle : sur une couverture,
/// le titre et l'auteur sont presque toujours les plus gros textes.
class OcrLine {
  final String text;
  final double height;
  const OcrLine(this.text, this.height);
}

/// Un mot reconnu, positionné dans les coordonnées pixels de l'image source.
class OcrWord {
  final String text;

  /// Position dans l'image source (pixels).
  final Rect rect;

  /// Index de la ligne dans l'ordre de lecture.
  final int lineIndex;

  /// Position du mot à l'intérieur de sa ligne.
  final int indexInLine;

  /// Dernier mot de sa ligne (utile pour recoller les mots coupés en fin de ligne).
  final bool lastOfLine;

  const OcrWord({
    required this.text,
    required this.rect,
    required this.lineIndex,
    required this.indexInLine,
    required this.lastOfLine,
  });
}

/// Une ligne de texte reconnue, avec ses mots.
class OcrTextLine {
  final int index;
  final Rect rect;
  final List<OcrWord> words;

  const OcrTextLine({
    required this.index,
    required this.rect,
    required this.words,
  });

  String get text => words.map((w) => w.text).join(' ');
}

/// Résultat structuré d'une reconnaissance de page.
class OcrPageResult {
  /// Taille de l'image source en pixels (référentiel des `rect`).
  final Size imageSize;
  final List<OcrTextLine> lines;

  /// Tous les mots, à plat, dans l'ordre de lecture. L'index dans cette liste
  /// sert d'identifiant de sélection (une sélection de passage = une plage
  /// contiguë d'index).
  final List<OcrWord> words;

  final String fullText;

  /// Numéro de page détecté en tête ou pied de page, si trouvé.
  final int? detectedPageNumber;

  const OcrPageResult({
    required this.imageSize,
    required this.lines,
    required this.words,
    required this.fullText,
    this.detectedPageNumber,
  });

  static const empty = OcrPageResult(
    imageSize: Size.zero,
    lines: [],
    words: [],
    fullText: '',
  );

  bool get isEmpty => words.isEmpty;
}

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// En dessous de ce nombre de lettres reconnues, on considère que la photo
  /// a mal été lue et on retente sur une copie contrastée/agrandie.
  static const int _minLettersBeforeRetry = 80;

  // ──────────────────────────────────────────────────────────────────
  // Reconnaissance structurée (surlignage de passage)
  // ──────────────────────────────────────────────────────────────────

  /// Reconnaît une page complète : mots positionnés, lignes remises dans
  /// l'ordre de lecture (colonnes gérées), numéro de page détecté.
  ///
  /// Deux passes : la photo d'origine, puis — seulement si le résultat est
  /// pauvre et si [enhanceFallback] est vrai — une copie en niveaux de gris
  /// contrastés (et agrandie si la photo est petite). On garde la meilleure
  /// des deux.
  ///
  /// [enhanceFallback] doit rester à `false` pour un simple gros plan (scan du
  /// numéro de page) : peu de texte y est normal, la seconde passe coûterait
  /// un décodage + un PNG temporaire pour rien.
  Future<OcrPageResult> recognizePage(
    String imagePath, {
    bool enhanceFallback = true,
  }) async {
    final size = await ImageOps.readSize(imagePath);
    if (size == null) return OcrPageResult.empty;

    OcrPageResult first;
    try {
      first = await _recognize(imagePath, size, 1.0);
    } catch (e) {
      debugPrint('OCR recognizePage (pass 1): $e');
      // On garde la taille de l'image : la photo reste affichable et le repli
      // IA reste possible même sans un seul mot reconnu.
      first = OcrPageResult(
        imageSize: size,
        lines: const [],
        words: const [],
        fullText: '',
      );
    }

    if (!enhanceFallback ||
        _letterCount(first.fullText) >= _minLettersBeforeRetry) {
      return first;
    }

    final enhanced = await ImageOps.enhanceForOcr(imagePath);
    if (enhanced == null) return first;

    try {
      final second = await _recognize(enhanced.path, size, enhanced.scale);
      return _letterCount(second.fullText) > _letterCount(first.fullText)
          ? second
          : first;
    } catch (e) {
      debugPrint('OCR recognizePage (pass 2): $e');
      return first;
    } finally {
      try {
        File(enhanced.path).deleteSync();
      } catch (_) {}
    }
  }

  Future<OcrPageResult> _recognize(
    String path,
    Size imageSize,
    double scale,
  ) async {
    final recognized =
        await _textRecognizer.processImage(InputImage.fromFilePath(path));

    final raw = <_RawLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;

        final rect = _descale(line.boundingBox, scale);
        final words = <_RawWord>[];
        for (final element in line.elements) {
          final t = element.text.trim();
          if (t.isEmpty) continue;
          words.add(_RawWord(t, _descale(element.boundingBox, scale)));
        }
        // Certains moteurs ne remontent pas les éléments : on répartit alors
        // les mots proportionnellement sur la largeur de la ligne.
        if (words.isEmpty) words.addAll(_splitLine(text, rect));

        raw.add(_RawLine(rect, words));
      }
    }

    final ordered = _readingOrder(raw);

    final lines = <OcrTextLine>[];
    final words = <OcrWord>[];
    for (var i = 0; i < ordered.length; i++) {
      final rawLine = ordered[i];
      final lineWords = <OcrWord>[];
      for (var j = 0; j < rawLine.words.length; j++) {
        final w = OcrWord(
          text: rawLine.words[j].text,
          rect: rawLine.words[j].rect,
          lineIndex: i,
          indexInLine: j,
          lastOfLine: j == rawLine.words.length - 1,
        );
        lineWords.add(w);
        words.add(w);
      }
      lines.add(OcrTextLine(index: i, rect: rawLine.rect, words: lineWords));
    }

    return OcrPageResult(
      imageSize: imageSize,
      lines: lines,
      words: words,
      fullText: buildText(words),
      detectedPageNumber: _detectPageNumber(lines, imageSize),
    );
  }

  static Rect _descale(Rect rect, double scale) {
    if (scale == 1.0) return rect;
    return Rect.fromLTRB(
      rect.left / scale,
      rect.top / scale,
      rect.right / scale,
      rect.bottom / scale,
    );
  }

  /// Répartition approximative des mots d'une ligne sur sa bounding box.
  static List<_RawWord> _splitLine(String text, Rect rect) {
    final parts = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return const [];
    final totalChars = parts.fold<int>(0, (sum, p) => sum + p.length + 1);
    if (totalChars == 0) return const [];

    final result = <_RawWord>[];
    var cursor = rect.left;
    for (final part in parts) {
      final width = rect.width * ((part.length + 1) / totalChars);
      result.add(
        _RawWord(part, Rect.fromLTWH(cursor, rect.top, width, rect.height)),
      );
      cursor += width;
    }
    return result;
  }

  // ── Ordre de lecture ──

  /// Remet les lignes dans l'ordre de lecture : colonnes de gauche à droite,
  /// puis lignes de haut en bas à l'intérieur de chaque colonne.
  static List<_RawLine> _readingOrder(List<_RawLine> lines) {
    if (lines.length < 2) return lines;

    final result = <_RawLine>[];
    for (final column in _splitColumns(lines)) {
      result.addAll(_sortColumn(column));
    }
    return result;
  }

  static List<_RawLine> _sortColumn(List<_RawLine> lines) {
    final sorted = [...lines]
      ..sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));

    // Regroupement en « rangées » : deux lignes dont les centres verticaux se
    // touchent appartiennent à la même rangée (titre + numéro, notes de bas
    // de page côte à côte…) et se lisent de gauche à droite.
    final result = <_RawLine>[];
    var row = <_RawLine>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final line = sorted[i];
      final reference = row.last;
      final tolerance =
          math.min(reference.rect.height, line.rect.height) * 0.55;
      if ((line.rect.center.dy - reference.rect.center.dy).abs() <= tolerance) {
        row.add(line);
      } else {
        row.sort((a, b) => a.rect.left.compareTo(b.rect.left));
        result.addAll(row);
        row = <_RawLine>[line];
      }
    }
    row.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    result.addAll(row);
    return result;
  }

  /// Détecte une mise en page à deux colonnes via la « gouttière » verticale
  /// vide au milieu du bloc de texte. Retourne une seule colonne si le doute
  /// subsiste (cas très majoritaire d'un roman).
  static List<List<_RawLine>> _splitColumns(List<_RawLine> lines) {
    if (lines.length < 6) return [lines];

    var left = double.infinity;
    var right = -double.infinity;
    for (final l in lines) {
      left = math.min(left, l.rect.left);
      right = math.max(right, l.rect.right);
    }
    final width = right - left;
    if (width <= 0) return [lines];

    const buckets = 100;
    final coverage = List<int>.filled(buckets, 0);
    for (final l in lines) {
      final start =
          (((l.rect.left - left) / width) * buckets).floor().clamp(0, buckets - 1);
      final end =
          (((l.rect.right - left) / width) * buckets).ceil().clamp(1, buckets);
      for (var i = start; i < end; i++) {
        coverage[i]++;
      }
    }

    var bestStart = -1, bestLength = 0, currentStart = -1;
    for (var i = (buckets * 0.25).round(); i < (buckets * 0.75).round(); i++) {
      if (coverage[i] == 0) {
        if (currentStart < 0) currentStart = i;
        final length = i - currentStart + 1;
        if (length > bestLength) {
          bestLength = length;
          bestStart = currentStart;
        }
      } else {
        currentStart = -1;
      }
    }

    // Gouttière trop fine → page à une seule colonne.
    if (bestLength < 6 || bestStart < 0) return [lines];

    final splitX = left + ((bestStart + bestLength / 2) / buckets) * width;
    final first = lines.where((l) => l.rect.center.dx < splitX).toList();
    final second = lines.where((l) => l.rect.center.dx >= splitX).toList();
    if (first.length < 3 || second.length < 3) return [lines];
    return [first, second];
  }

  // ── Assemblage et nettoyage du texte ──

  /// Assemble une sélection de mots en un texte propre : ordre de lecture,
  /// mots coupés en fin de ligne recollés, espaces et apostrophes normalisés.
  static String buildText(Iterable<OcrWord> selection) {
    final words = [...selection]..sort((a, b) {
        final byLine = a.lineIndex.compareTo(b.lineIndex);
        return byLine != 0 ? byLine : a.indexInLine.compareTo(b.indexInLine);
      });
    if (words.isEmpty) return '';

    final buffer = StringBuffer(words.first.text);
    for (var i = 1; i < words.length; i++) {
      final previous = words[i - 1];
      final current = words[i];

      final newLine = current.lineIndex != previous.lineIndex;
      if (newLine && previous.lastOfLine && _isHyphenated(previous.text, current.text)) {
        // Césure typographique : « géo- / graphie » → « géographie »
        final joined = buffer.toString();
        buffer
          ..clear()
          ..write(joined.substring(0, joined.length - 1));
      } else {
        buffer.write(' ');
      }
      buffer.write(current.text);
    }

    return cleanupText(buffer.toString());
  }

  static bool _isHyphenated(String previous, String next) {
    if (previous.length < 2) return false;
    // Une lettre (suivie de ses éventuels accents décomposés) puis un tiret.
    if (!RegExp(r'\p{L}\p{M}*[-‐‑–]$', unicode: true).hasMatch(previous)) {
      return false;
    }
    // Un mot coupé reprend en minuscule ; « Jean-\nPierre » reste intact.
    return RegExp(r'^\p{Ll}', unicode: true).hasMatch(next);
  }

  /// Nettoyage conservateur des artefacts OCR les plus fréquents.
  static String cleanupText(String input) {
    var text = input;

    // Traits d'union conditionnels et espaces exotiques.
    text = text.replaceAll('\u00AD', '');
    text = text.replaceAll(RegExp('[\u00A0\u202F\u2009\t]'), ' ');

    // Apostrophes : « l ' homme » / « l ‘ homme » → « l'homme ».
    text = text.replaceAllMapped(
      RegExp(r"(\p{L})\s*['’‘`´]\s*(\p{L})", unicode: true),
      (m) => '${m[1]}’${m[2]}',
    );

    // Guillemets français.
    text = text.replaceAll(RegExp(r'«\s*'), '« ');
    text = text.replaceAll(RegExp(r'\s*»'), ' »');

    // Espace parasite avant une virgule ou un point.
    text = text.replaceAllMapped(RegExp(r'\s+([,.])'), (m) => m[1]!);
    // Plusieurs espaces avant une ponctuation haute → un seul (typo française).
    text = text.replaceAllMapped(RegExp(r'\s{2,}([;:!?])'), (m) => ' ${m[1]}');

    text = text.replaceAll(RegExp(r'\(\s+'), '(');
    text = text.replaceAll(RegExp(r'\s+\)'), ')');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  static int _letterCount(String text) =>
      RegExp(r'\p{L}', unicode: true).allMatches(text).length;

  // ── Numéro de page ──

  /// Cherche un numéro de page dans les 15 % du haut ou du bas de la photo,
  /// là où il se trouve réellement — bien plus fiable que « le plus petit
  /// nombre de la page ».
  static int? _detectPageNumber(List<OcrTextLine> lines, Size imageSize) {
    if (lines.isEmpty || imageSize.height <= 0) return null;

    final topLimit = imageSize.height * 0.15;
    final bottomLimit = imageSize.height * 0.85;

    final top = <int>[];
    final bottom = <int>[];
    for (final line in lines) {
      final centerY = line.rect.center.dy;
      if (centerY > topLimit && centerY < bottomLimit) continue;

      final text = line.text.trim();
      final standalone =
          RegExp(r'^[\-—–|\s]*(\d{1,4})[\-—–|\s]*$').firstMatch(text);
      final labelled = RegExp(r'(?:page|p\.?)\s*(\d{1,4})', caseSensitive: false)
          .firstMatch(text);
      final raw = standalone?.group(1) ?? labelled?.group(1);
      if (raw == null) continue;

      final value = int.tryParse(raw);
      if (value == null || value <= 0 || value >= 10000) continue;
      (centerY >= bottomLimit ? bottom : top).add(value);
    }

    // Le pied de page l'emporte (emplacement le plus courant). Sur une double
    // page on garde le plus grand des deux numéros : c'est là qu'on s'arrête.
    final candidates = bottom.isNotEmpty ? bottom : top;
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.last;
  }

  // ──────────────────────────────────────────────────────────────────
  // API historique (scan de couverture, ISBN, numéro de page)
  // ──────────────────────────────────────────────────────────────────

  /// Extrait toutes les lignes de texte avec leur hauteur de bounding box.
  /// Utilisé par le scan couverture pour identifier titre/auteur par taille
  /// de texte plutôt que par longueur de ligne.
  Future<List<OcrLine>> extractLines(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final lines = <OcrLine>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          lines.add(OcrLine(text, line.boundingBox.height.toDouble()));
        }
      }
      return lines;
    } catch (e) {
      debugPrint('OCR extractLines error: $e');
      return [];
    }
  }

  /// Extract page number from an image
  /// Returns null if no page number could be detected
  Future<int?> extractPageNumber(String imagePath) async {
    try {
      // 1. Détection par position : on ne cherche le numéro que dans la tête
      //    et le pied de page, là où il se trouve réellement.
      //    Pas de seconde passe contrastée ici : un gros plan de coin de page
      //    contient peu de texte par nature, la relancer coûterait cher pour
      //    rien.
      final page = await recognizePage(imagePath, enhanceFallback: false);
      if (page.detectedPageNumber != null) return page.detectedPageNumber;

      // 2. Repli : ancienne heuristique, appliquée au texte déjà reconnu
      //    (aucune passe OCR supplémentaire).
      return _findPageNumberInLines(page.lines.map((l) => l.text));
    } catch (e) {
      debugPrint('OCR Error: $e');
      return null;
    }
  }

  /// Intelligent page number detection
  /// Heuristique historique : on ratisse toutes les lignes reconnues et on
  /// garde le nombre le plus plausible. Sert de repli quand la détection par
  /// position (tête/pied de page) n'a rien donné.
  int? _findPageNumberInLines(Iterable<String> lines) {
    List<int> candidates = [];

    for (String rawLine in lines) {
      {
        String lineText = rawLine.trim();

        // Strategy 1: Standalone number (most common for page numbers)
        if (RegExp(r'^\d+$').hasMatch(lineText)) {
          int? number = int.tryParse(lineText);
          if (number != null) {
            candidates.add(number);
          }
        }

        // Strategy 2: "Page XXX" or "p. XXX" or "p XXX"
        RegExp pagePattern = RegExp(
          r'(?:page|p\.?)\s*(\d+)',
          caseSensitive: false,
        );
        Match? match = pagePattern.firstMatch(lineText);
        if (match != null) {
          int? number = int.tryParse(match.group(1)!);
          if (number != null) {
            candidates.add(number);
          }
        }

        // Strategy 3: "XXX |" or "| XXX" (common page number formats)
        RegExp pipePattern = RegExp(r'(\d+)\s*\||\|\s*(\d+)');
        Match? pipeMatch = pipePattern.firstMatch(lineText);
        if (pipeMatch != null) {
          String? numberStr = pipeMatch.group(1) ?? pipeMatch.group(2);
          if (numberStr != null) {
            int? number = int.tryParse(numberStr);
            if (number != null) {
              candidates.add(number);
            }
          }
        }

        // Strategy 4: "- XXX -" (centered page numbers)
        RegExp dashPattern = RegExp(r'-\s*(\d+)\s*-');
        Match? dashMatch = dashPattern.firstMatch(lineText);
        if (dashMatch != null) {
          int? number = int.tryParse(dashMatch.group(1)!);
          if (number != null) {
            candidates.add(number);
          }
        }
      }
    }

    // Filter out invalid candidates
    candidates = candidates.where((n) {
      // Page numbers are typically between 1 and 9999
      return n > 0 && n < 10000;
    }).toList();

    // Remove duplicates
    candidates = candidates.toSet().toList();

    if (candidates.isEmpty) return null;

    // Heuristic: Take the smallest number
    // (page numbers are usually smaller than dates, ISBNs, etc.)
    candidates.sort();

    // If we have multiple candidates, prefer numbers under 1000
    // as they're more likely to be page numbers
    List<int> preferredCandidates = candidates.where((n) => n < 1000).toList();
    if (preferredCandidates.isNotEmpty) {
      return preferredCandidates.first;
    }

    return candidates.first;
  }

  /// Extract ISBN from image (book cover or barcode area)
  /// Returns ISBN-13 or ISBN-10 if found
  Future<String?> extractISBN(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // ISBN patterns
      // ISBN-13: 978 or 979 followed by 10 digits (with optional hyphens/spaces)
      // ISBN-10: 10 digits or 9 digits + X (with optional hyphens/spaces)

      final RegExp isbn13Pattern = RegExp(
        r'(?:ISBN[:\-]?\s*)?(?:97[89])[\-\s]?\d[\-\s]?\d{2}[\-\s]?\d{5,6}[\-\s]?\d',
        caseSensitive: false,
      );

      final RegExp isbn10Pattern = RegExp(
        r'(?:ISBN[:\-]?\s*)?\d[\-\s]?\d{2}[\-\s]?\d{5,6}[\-\s]?[\dXx]',
        caseSensitive: false,
      );

      // Also match pure digit sequences that look like ISBNs
      final RegExp pureIsbn13 = RegExp(r'97[89]\d{10}');
      final RegExp pureIsbn10 = RegExp(r'\d{9}[\dXx]');

      String fullText = recognizedText.text;

      // Try ISBN-13 first (preferred)
      Match? match = isbn13Pattern.firstMatch(fullText);
      if (match != null) {
        String isbn = _cleanISBN(match.group(0)!);
        if (_isValidISBN13(isbn)) {
          return isbn;
        }
      }

      // Try pure ISBN-13
      match = pureIsbn13.firstMatch(fullText.replaceAll(RegExp(r'[\s\-]'), ''));
      if (match != null) {
        String isbn = match.group(0)!;
        if (_isValidISBN13(isbn)) {
          return isbn;
        }
      }

      // Try ISBN-10
      match = isbn10Pattern.firstMatch(fullText);
      if (match != null) {
        String isbn = _cleanISBN(match.group(0)!);
        if (_isValidISBN10(isbn)) {
          return isbn;
        }
      }

      // Try pure ISBN-10
      match = pureIsbn10.firstMatch(fullText.replaceAll(RegExp(r'[\s\-]'), ''));
      if (match != null) {
        String isbn = match.group(0)!;
        if (_isValidISBN10(isbn)) {
          return isbn;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting ISBN: $e');
      return null;
    }
  }

  /// Clean ISBN string (remove ISBN prefix, hyphens, spaces)
  String _cleanISBN(String isbn) {
    return isbn
        .toUpperCase()
        .replaceAll(RegExp(r'ISBN[:\-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s\-]'), '');
  }

  /// Validate ISBN-13 checksum
  bool _isValidISBN13(String isbn) {
    if (isbn.length != 13) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(isbn)) return false;

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(isbn[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(isbn[12]);
  }

  /// Validate ISBN-10 checksum
  bool _isValidISBN10(String isbn) {
    if (isbn.length != 10) return false;
    if (!RegExp(r'^\d{9}[\dXx]$').hasMatch(isbn)) return false;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(isbn[i]) * (10 - i);
    }
    int lastDigit = isbn[9].toUpperCase() == 'X' ? 10 : int.parse(isbn[9]);
    sum += lastDigit;

    return sum % 11 == 0;
  }

  /// Get all detected text for debugging
  Future<String> extractAllText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      return recognizedText.text;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Get detailed text blocks for advanced debugging
  Future<List<Map<String, dynamic>>> extractTextBlocks(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      List<Map<String, dynamic>> blocks = [];

      for (TextBlock block in recognizedText.blocks) {
        blocks.add({
          'text': block.text,
          'rect': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
          'lines': block.lines.map((line) => line.text).toList(),
        });
      }

      return blocks;
    } catch (e) {
      debugPrint('Error extracting text blocks: $e');
      return [];
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}

// ── Structures internes de reconnaissance ──

class _RawWord {
  final String text;
  final Rect rect;
  const _RawWord(this.text, this.rect);
}

class _RawLine {
  final Rect rect;
  final List<_RawWord> words;
  const _RawLine(this.rect, this.words);
}

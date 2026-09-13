// lib/pages/books/scan_book_cover_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../l10n/app_localizations.dart';
import '../../services/ocr_service.dart';
import '../../services/google_books_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import 'manual_book_search_page.dart';

/// Mode de scan actif
enum ScanMode {
  barcode, // Scan code-barres ISBN (prioritaire)
  ocr, // OCR couverture (fallback)
}

class ScanBookCoverPage extends StatefulWidget {
  const ScanBookCoverPage({super.key});

  @override
  State<ScanBookCoverPage> createState() => _ScanBookCoverPageState();
}

class _ScanBookCoverPageState extends State<ScanBookCoverPage>
    with SingleTickerProviderStateMixin {
  final OCRService _ocrService = OCRService();
  final GoogleBooksService _googleBooksService = GoogleBooksService();
  final ImagePicker _picker = ImagePicker();

  // Scanner controller
  MobileScannerController? _scannerController;

  // State
  ScanMode _currentMode = ScanMode.barcode;
  XFile? _imageFile;
  String? _extractedText;
  String? _detectedISBN;
  List<GoogleBook> _searchResults = [];
  bool _isProcessing = false;
  bool _isSearching = false;
  String? _errorMessage;
  String? _successMessage;
  bool _scannerActive = true;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initScanner();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _scannerController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Callback quand un code-barres est détecté
  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_scannerActive || _isProcessing || _isSearching) return;

    for (final barcode in capture.barcodes) {
      final String? code = barcode.rawValue;
      if (code == null) continue;

      // Vérifier si c'est un ISBN (commence par 978 ou 979)
      if (code.length == 13 && (code.startsWith('978') || code.startsWith('979'))) {
        setState(() {
          _scannerActive = false;
          _detectedISBN = code;
          _successMessage = AppLocalizations.of(context).scanIsbnDetected(code);
        });

        // Rechercher le livre
        await _searchByISBN(code);
        return;
      }
    }
  }

  /// Rechercher un livre par ISBN
  Future<void> _searchByISBN(String isbn) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final book = await _googleBooksService.searchByISBN(isbn);

      if (book != null) {
        if (!mounted) return;
        setState(() {
          _searchResults = [book];
          _isSearching = false;
        });
      } else {
        // Pas trouvé par ISBN, essayer recherche générique
        final results = await _googleBooksService.searchBooks(isbn);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearching = false;
          if (results.isEmpty) {
            _errorMessage = AppLocalizations.of(context).scanNoBookForIsbn;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = AppLocalizations.of(context).scanSearchError(e.toString());
      });
    }
  }

  /// Basculer vers le mode OCR (photo couverture)
  void _switchToOCRMode() {
    setState(() {
      _currentMode = ScanMode.ocr;
      _scannerActive = false;
      _errorMessage = null;
      _successMessage = null;
      _searchResults = [];
    });
  }

  /// Basculer vers le mode code-barres
  void _switchToBarcodeMode() {
    setState(() {
      _currentMode = ScanMode.barcode;
      _scannerActive = true;
      _errorMessage = null;
      _successMessage = null;
      _searchResults = [];
      _imageFile = null;
      _extractedText = null;
      _detectedISBN = null;
    });
  }

  /// Prendre une photo de la couverture (mode OCR)
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );

      if (photo == null) return;
      await _processImage(photo);
    } catch (e) {
      if (!mounted) return;
      // Permission caméra refusée : l'exception brute du plugin ne dit rien à
      // l'utilisateur et ne propose aucune suite. On nomme le problème et on
      // ouvre les deux sorties possibles (réglages, recherche par titre).
      if (_isCameraPermissionError(e)) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).cameraPermissionHint;
        });
        _showCameraPermissionSnack();
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context).errorCapture(e.toString());
      });
    }
  }

  /// Vrai si l'erreur remontée par image_picker est un refus de permission.
  bool _isCameraPermissionError(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('camera_access_denied') ||
        text.contains('access_denied') ||
        text.contains('permission');
  }

  void _showCameraPermissionSnack() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.cameraPermissionDenied),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l.openSettings,
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  /// Caméra indisponible (permission refusée, matériel occupé). Sans ce
  /// builder, `MobileScanner` peint la surface d'erreur brute du plugin :
  /// écran mort, aucun message, aucune sortie. Le parcours d'ajout de livre
  /// s'arrêtait définitivement ici.
  Widget _buildScannerError() {
    final l = AppLocalizations.of(context);
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 44),
            const SizedBox(height: 12),
            Text(
              l.cameraPermissionDenied,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.cameraPermissionHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _manualSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(l.searchByTitleButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: openAppSettings,
                  child: Text(
                    l.openSettings,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionner depuis la galerie
  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (photo == null) return;
      await _processImage(photo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).errorSelection(e.toString());
      });
    }
  }

  /// Traiter l'image avec OCR
  Future<void> _processImage(XFile photo) async {
    setState(() {
      _imageFile = photo;
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
      _searchResults = [];
    });

    try {
      // 1. D'abord essayer d'extraire un ISBN de l'image
      final isbn = await _ocrService.extractISBN(photo.path);

      if (isbn != null) {
        if (!mounted) return;
        setState(() {
          _detectedISBN = isbn;
          _successMessage = AppLocalizations.of(context).scanIsbnDetected(isbn);
          _isProcessing = false;
        });
        await _searchByISBN(isbn);
        return;
      }

      // 2. Sinon, extraire les lignes de texte avec leur taille (bounding box)
      final lines = await _ocrService.extractLines(photo.path);
      final text = lines.map((l) => l.text).join('\n');

      if (!mounted) return;
      setState(() {
        _extractedText = text;
        _isProcessing = false;
      });

      if (text.isEmpty) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).scanNoTextDetected;
        });
        return;
      }

      // 3. Rechercher sur Google Books
      await _searchOnGoogleBooks(lines, text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur OCR: $e';
      });
    }
  }

  /// True si la ligne est du "bruit" (éditeur, mentions marketing, dates…)
  /// et ne peut pas être un titre ou un auteur.
  bool _isNoiseLine(String l) {
    if (l.length <= 2) return true;
    // Dates / numéros purs
    if (RegExp(r'^\d[\d\s\-\./:]*$').hasMatch(l)) return true;

    final lower = l.toLowerCase();
    const noiseExact = [
      // Éditeurs
      'texto', 'folio', 'poche', 'pocket', 'j\'ai lu', 'livre de poche',
      'gallimard', 'hachette', 'flammarion', 'albin michel', 'seuil',
      'grasset', 'actes sud', 'points', 'babel', 'nathan', 'casterman',
      'bayard', 'milan', 'didier jeunesse', 'père castor',
      'l\'école des loisirs', 'ecole des loisirs', 'kaléidoscope',
      'kaleidoscope', 'gautier-languereau', 'auzou', 'fleurus',
      'larousse', 'robert laffont', 'calmann-lévy', 'calmann-levy',
      'le cherche midi', 'stock', 'jc lattès', 'jc lattes', 'belfond',
      'denoël', 'denoel', 'rivages', 'minuit', 'p.o.l', 'verdier',
      'zulma', 'sabine wespieser', 'l\'olivier', 'mercure de france',
      'penguin', 'harper collins', 'harpercollins', 'simon & schuster',
      'random house', 'macmillan', 'scholastic', 'bloomsbury',
      // Collections / types
      'edition', 'édition', 'editions', 'éditions', 'collection',
      'album', 'album nathan', 'album jeunesse', 'roman', 'essai',
      'bd', 'bande dessinée', 'manga', 'grand format',
      // Mentions marketing / interface (photo d'écran, page produit…)
      'isbn', 'prix', 'best-seller', 'bestseller', 'www.', 'http',
      'nouveau', 'nouveauté', 'nouveaute', 'inédit', 'inedit',
      'ebook', 'kindle', 'amazon', 'fnac', 'cultura', 'livres',
      'ajouter au panier', 'voir tous les détails', 'livraison',
      'broché', 'broche', 'relié', 'relie', 'format',
    ];
    if (noiseExact.any((n) => lower == n || lower.startsWith('$n '))) {
      return true;
    }
    // "Éditions X" / "Collection X"
    if (RegExp(r'^(éditions?|editions?|collection)\b', caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }
    // Copyright/année
    if (RegExp(r'^[©®]\s*\d{4}').hasMatch(l)) return true;
    // Notes type "4,6 étoiles", pourcentages, prix en euros
    if (RegExp(r'^\d+[,.]\d+\s*[€%★*]?$').hasMatch(l)) return true;
    if (l.contains('€')) return true;
    return false;
  }

  /// Normalise une chaîne pour comparaison : minuscules, sans accents,
  /// caractères non alphanumériques remplacés par des espaces.
  String _normalize(String s) {
    const accents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœæ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    var out = s.toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      out = out.replaceAll(accents[i], plain[i]);
    }
    return out
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Classe les lignes OCR par hauteur de texte décroissante (le titre et
  /// l'auteur sont presque toujours les plus gros textes de l'image),
  /// après filtrage du bruit et dédoublonnage.
  List<String> _candidateLines(List<OcrLine> lines) {
    final filtered = lines.where((l) => !_isNoiseLine(l.text)).toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    final seen = <String>{};
    final out = <String>[];
    for (final l in filtered) {
      final key = _normalize(l.text);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(l.text);
    }
    return out;
  }

  /// Ne garde que les résultats dont le titre ou l'auteur recoupe réellement
  /// le texte OCR — évite d'afficher des livres au hasard renvoyés par le
  /// fuzzy matching de Google Books. Trie par pertinence du titre.
  List<GoogleBook> _filterRelevant(List<GoogleBook> results, String ocrText) {
    final haystack = ' ${_normalize(ocrText)} ';

    double titleScore(GoogleBook book) {
      final tokens = _normalize(book.title)
          .split(' ')
          .where((t) => t.length >= 3)
          .toList();
      if (tokens.isEmpty) return 0;
      final found = tokens.where((t) => haystack.contains(' $t ')).length;
      return found / tokens.length;
    }

    bool authorMatches(GoogleBook book) {
      return book.authors.any((a) {
        final tokens =
            _normalize(a).split(' ').where((t) => t.length >= 3).toList();
        return tokens.isNotEmpty &&
            tokens.every((t) => haystack.contains(' $t '));
      });
    }

    final scored = <(GoogleBook, double)>[];
    for (final book in results) {
      final score = titleScore(book);
      if (score >= 0.5 || authorMatches(book)) {
        scored.add((book, score));
      }
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  /// Rechercher sur Google Books à partir des lignes OCR classées par taille
  /// de texte. Cascade de requêtes, chaque étape filtrée par pertinence ;
  /// fallback IA (Edge Function) en dernier recours.
  Future<void> _searchOnGoogleBooks(List<OcrLine> lines, String rawText) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final candidates = _candidateLines(lines);
      debugPrint('OCR candidates (par taille): ${candidates.take(5).toList()}');

      var results = <GoogleBook>[];

      if (candidates.isNotEmpty) {
        // 1. Requête combinée avec les 3 plus gros textes (titre + auteur
        //    y sont presque toujours), restreinte au français d'abord.
        final combined = candidates.take(3).join(' ');
        debugPrint('OCR query 1: "$combined" (fr)');
        results = _filterRelevant(
          await _googleBooksService.searchBooks(combined, langRestrict: true),
          rawText,
        );

        // 2. Même requête sans restriction de langue
        if (results.isEmpty) {
          debugPrint('OCR query 2: "$combined"');
          results = _filterRelevant(
            await _googleBooksService.searchBooks(combined),
            rawText,
          );
        }

        // 3. intitle:/inauthor: dans les deux sens (on ne sait pas lequel des
        //    deux plus gros textes est le titre et lequel est l'auteur)
        if (results.isEmpty && candidates.length >= 2) {
          final a = candidates[0], b = candidates[1];
          debugPrint('OCR query 3: intitle/inauthor');
          results = _filterRelevant(
            await _googleBooksService.searchBooks('intitle:$b inauthor:$a'),
            rawText,
          );
          if (results.isEmpty) {
            results = _filterRelevant(
              await _googleBooksService.searchBooks('intitle:$a inauthor:$b'),
              rawText,
            );
          }
        }

        // 4. Chaque candidat seul (toujours filtré par pertinence, donc pas
        //    de résultats hors sujet)
        if (results.isEmpty) {
          for (final c in candidates.take(3)) {
            debugPrint('OCR query 4: "$c"');
            results = _filterRelevant(
              await _googleBooksService.searchBooks(c),
              rawText,
            );
            if (results.isNotEmpty) break;
          }
        }
      }

      // 5. Fallback IA : extraction titre/auteur par la Edge Function
      if (results.isEmpty) {
        results = await _aiFallbackSearch(rawText);
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).scanNoBookFound;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = AppLocalizations.of(context).scanSearchError(e.toString());
      });
    }
  }

  /// Fallback IA : envoie le texte OCR à la Edge Function
  /// `extract-book-from-cover` (gpt-4o-mini) qui en extrait titre + auteur,
  /// puis recherche sur Google Books. Best-effort : toute erreur (pas de
  /// réseau, mode invité, quota…) retourne simplement une liste vide.
  Future<List<GoogleBook>> _aiFallbackSearch(String rawText) async {
    try {
      debugPrint('OCR fallback IA: extraction titre/auteur');
      final response = await Supabase.instance.client.functions.invoke(
        'extract-book-from-cover',
        body: {'ocr_text': rawText},
      );

      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is String ? jsonDecode(data) as Map<String, dynamic> : null);
      if (map == null) return [];

      final title = (map['title'] as String?)?.trim() ?? '';
      final author = (map['author'] as String?)?.trim() ?? '';
      if (title.isEmpty) return [];
      debugPrint('OCR fallback IA: titre="$title" auteur="$author"');

      var results = <GoogleBook>[];
      if (author.isNotEmpty) {
        results = await _googleBooksService.searchByTitleAuthor(title, author);
      }
      if (results.isEmpty) {
        results =
            await _googleBooksService.searchBooks('$title $author'.trim());
      }
      // Filtre de pertinence contre le texte OCR enrichi du titre/auteur
      // extraits (l'IA peut avoir corrigé une coquille OCR).
      return _filterRelevant(results, '$rawText\n$title\n$author');
    } catch (e) {
      debugPrint('OCR fallback IA erreur: $e');
      return [];
    }
  }

  /// Recherche manuelle — délègue à une page plein écran dédiée.
  /// Si l'utilisateur sélectionne un livre, on pop directement vers l'appelant
  /// (ex: le FAB) avec ce livre, comme pour un scan réussi.
  Future<void> _manualSearch() async {
    final selected = await Navigator.of(context).push<GoogleBook>(
      MaterialPageRoute(
        builder: (_) => const ManualBookSearchPage(),
      ),
    );
    if (!mounted || selected == null) return;
    Navigator.of(context).pop(selected);
  }

  /// Réessayer le scan
  void _retry() {
    setState(() {
      _scannerActive = true;
      _errorMessage = null;
      _successMessage = null;
      _searchResults = [];
      _detectedISBN = null;
      _extractedText = null;
      _imageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMode == ScanMode.barcode
            ? AppLocalizations.of(context).scanIsbnTitle
            : AppLocalizations.of(context).scanCoverTitle),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _manualSearch,
            tooltip: AppLocalizations.of(context).manualSearchTooltip,
          ),
        ],
      ),
      body: ConstrainedContent(
        child: Column(
          children: [
            // Mode selector
            _buildModeSelector(),

            // Main content
            Expanded(
              child: _currentMode == ScanMode.barcode
                  ? _buildBarcodeScanner()
                  : _buildOCRScanner(),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélecteur de mode (onglets)
  Widget _buildModeSelector() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _currentMode != ScanMode.barcode ? _switchToBarcodeMode : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _currentMode == ScanMode.barcode
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: _currentMode == ScanMode.barcode
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).barcodeLabel,
                      style: TextStyle(
                        fontWeight: _currentMode == ScanMode.barcode
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _currentMode == ScanMode.barcode
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _currentMode != ScanMode.ocr ? _switchToOCRMode : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _currentMode == ScanMode.ocr
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      color: _currentMode == ScanMode.ocr
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).coverLabel,
                      style: TextStyle(
                        fontWeight: _currentMode == ScanMode.ocr
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _currentMode == ScanMode.ocr
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scanner de code-barres
  Widget _buildBarcodeScanner() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Scanner ou résultats
          if (_searchResults.isEmpty && !_isSearching) ...[
            // Zone de scan
            Container(
              height: 300,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  if (_scannerActive && _scannerController != null)
                    MobileScanner(
                      controller: _scannerController!,
                      onDetect: _onBarcodeDetected,
                      errorBuilder: (context, error) => _buildScannerError(),
                    ),
                  if (!_scannerActive)
                    Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_detectedISBN != null) ...[
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'ISBN: $_detectedISBN',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ] else ...[
                              const Icon(Icons.pause_circle,
                                  color: Colors.white54, size: 48),
                              const SizedBox(height: 8),
                              Text(AppLocalizations.of(context).scanPaused,
                                  style: const TextStyle(color: Colors.white54)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  // Overlay guide
                  if (_scannerActive)
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 250 * _pulseAnimation.value,
                            height: 100 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                  width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Card(
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue),
                              const SizedBox(width: 8),
                              Text('Scan code-barres',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : null,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(AppLocalizations.of(context).scanPointCamera,
                              style: TextStyle(color: isDark ? Colors.white70 : null)),
                          Text(AppLocalizations.of(context).scanBarcodeHint,
                              style: TextStyle(color: isDark ? Colors.white70 : null)),
                          const SizedBox(height: 8),
                          Text(AppLocalizations.of(context).scanNoBarcodeHint,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white60 : null,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bouton retry si nécessaire
            if (!_scannerActive && _searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context).retry),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                ),
              ),
          ],

          // Messages
          _buildMessages(),

          // Loading
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).searchingInProgress),
                ],
              ),
            ),

          // Résultats
          _buildSearchResults(),
        ],
      ),
    );
  }

  /// Scanner OCR (photo couverture)
  Widget _buildOCRScanner() {
    final isInitial = _imageFile == null &&
        _searchResults.isEmpty &&
        !_isProcessing &&
        !_isSearching &&
        _errorMessage == null &&
        _successMessage == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.l,
        AppSpace.l,
        AppSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isInitial) ...[
            _buildOCRHero(),
            const SizedBox(height: AppSpace.l),
            _buildOCRSteps(),
            const SizedBox(height: AppSpace.xl),
          ],

          // Action principale
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _takePicture,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                AppLocalizations.of(context).takePhoto,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Center(
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(AppLocalizations.of(context).chooseFromGallery),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),

          if (isInitial) ...[
            const SizedBox(height: AppSpace.l),
            _buildIsbnTip(),
          ],

          // Processing
          if (_isProcessing) ...[
            const SizedBox(height: AppSpace.l),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context).scanAnalyzingCover),
                  ],
                ),
              ),
            ),
          ],

          // Messages
          _buildMessages(),

          // Loading recherche
          if (_isSearching && !_isProcessing)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context).searchingInProgress),
                  ],
                ),
              ),
            ),

          // Image preview
          if (_imageFile != null && !_isProcessing) ...[
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context).scanScannedCover,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(_imageFile!.path,
                      height: 250, fit: BoxFit.contain)
                  : Image.file(File(_imageFile!.path),
                      height: 250, fit: BoxFit.contain),
            ),
          ],

          // Texte extrait (debug)
          if (_extractedText != null && _extractedText!.isNotEmpty) ...[
            const SizedBox(height: 20),
            ExpansionTile(
              title: Text(AppLocalizations.of(context).scanDetectedText),
              children: [
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      child: Text(_extractedText!, style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
              ],
            ),
          ],

          // Résultats
          _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildOCRHero() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpace.l,
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context).scanPhotographCover,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).scanCoverExplain,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOCRSteps() {
    return Row(
      children: [
        _OCRStep(icon: Icons.camera_alt_outlined, label: AppLocalizations.of(context).scanStepPhoto),
        const SizedBox(width: AppSpace.s),
        _OCRStep(icon: Icons.text_fields_rounded, label: AppLocalizations.of(context).scanStepDetection),
        const SizedBox(width: AppSpace.s),
        _OCRStep(icon: Icons.auto_awesome_outlined, label: AppLocalizations.of(context).scanStepSearch),
      ],
    );
  }

  Widget _buildIsbnTip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpace.s),
          Flexible(
            child: Text(
              AppLocalizations.of(context).scanIsbnAutoDetect,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Messages (erreur / succès)
  Widget _buildMessages() {
    return Column(
      children: [
        if (_successMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_successMessage!,
                          style: TextStyle(color: Colors.green.shade900)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_errorMessage != null && !_isProcessing && !_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(color: Colors.orange.shade900)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Résultats de recherche
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: _currentMode == ScanMode.barcode
          ? const EdgeInsets.all(16)
          : const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).scanResults,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Nouveau scan'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._searchResults.map((book) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CachedBookCover(
                    imageUrl: book.coverUrl,
                    isbn: book.isbn13,
                    googleId: book.id,
                    title: book.title,
                    author: book.authorsString,
                    width: 50,
                    height: 70,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title:
                      Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.authorsString,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (book.publishedDate != null)
                        Text('${book.publishedDate}',
                            style: const TextStyle(fontSize: 12)),
                      if (book.isbn13 != null && book.isbn13!.isNotEmpty)
                        Text('ISBN: ${book.isbn13}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(context, book),
                ),
              )),
        ],
      ),
    );
  }
}

class _OCRStep extends StatelessWidget {
  final IconData icon;
  final String label;
  const _OCRStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

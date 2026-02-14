// lib/pages/books/scan_book_cover_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/ocr_service.dart';
import '../../services/google_books_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

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
          _successMessage = 'ISBN détecté: $code';
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
        setState(() {
          _searchResults = [book];
          _isSearching = false;
        });
      } else {
        // Pas trouvé par ISBN, essayer recherche générique
        final results = await _googleBooksService.searchBooks(isbn);
        setState(() {
          _searchResults = results;
          _isSearching = false;
          if (results.isEmpty) {
            _errorMessage = 'Aucun livre trouvé pour cet ISBN. Essayez le scan de couverture.';
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Erreur de recherche: $e';
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
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return;
      await _processImage(photo);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la capture: $e';
      });
    }
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
      setState(() {
        _errorMessage = 'Erreur lors de la sélection: $e';
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
        setState(() {
          _detectedISBN = isbn;
          _successMessage = 'ISBN détecté: $isbn';
          _isProcessing = false;
        });
        await _searchByISBN(isbn);
        return;
      }

      // 2. Sinon, extraire le texte de la couverture
      final text = await _ocrService.extractAllText(photo.path);

      setState(() {
        _extractedText = text;
        _isProcessing = false;
      });

      if (text.isEmpty) {
        setState(() {
          _errorMessage = 'Aucun texte détecté sur la couverture.';
        });
        return;
      }

      // 3. Rechercher sur Google Books
      await _searchOnGoogleBooks(text);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur OCR: $e';
      });
    }
  }

  /// Nettoie le texte OCR pour en extraire une requête pertinente
  String _cleanOCRQuery(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => l.length > 2) // Ignorer lignes trop courtes
        .where((l) => !RegExp(r'^\d[\d\s\-\./:]*$').hasMatch(l)) // Ignorer dates/numéros purs
        .where((l) {
          // Ignorer les noms d'éditeurs/collections courants
          final lower = l.toLowerCase();
          const noise = [
            'texto', 'folio', 'poche', 'pocket', 'j\'ai lu', 'livre de poche',
            'gallimard', 'hachette', 'flammarion', 'albin michel', 'seuil',
            'grasset', 'actes sud', 'points', 'babel', 'edition', 'édition',
            'editions', 'éditions', 'collection', 'isbn', 'roman', 'essai',
            'prix', 'best-seller', 'bestseller', 'www.', 'http',
          ];
          return !noise.any((n) => lower == n || lower.startsWith('$n '));
        })
        .toList();

    if (lines.isEmpty) return rawText.trim();

    // Prendre les 2 lignes les plus longues (probablement titre + auteur)
    final sorted = List<String>.from(lines)..sort((a, b) => b.length.compareTo(a.length));
    return sorted.take(2).join(' ');
  }

  /// Rechercher sur Google Books avec le texte OCR
  Future<void> _searchOnGoogleBooks(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final cleanQuery = _cleanOCRQuery(query);
      debugPrint('OCR search query: "$cleanQuery"');

      var results = await _googleBooksService.searchBooks(cleanQuery);

      // Si pas de résultat, essayer avec seulement la ligne la plus longue (titre probable)
      if (results.isEmpty) {
        final fallbackLines = query
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.length > 3)
            .toList();
        if (fallbackLines.isNotEmpty) {
          // Essayer la ligne la plus longue seule
          fallbackLines.sort((a, b) => b.length.compareTo(a.length));
          final fallbackQuery = fallbackLines.first;
          debugPrint('OCR fallback query: "$fallbackQuery"');
          results = await _googleBooksService.searchBooks(fallbackQuery);
        }
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        setState(() {
          _errorMessage = 'Aucun livre trouvé. Essayez la recherche manuelle.';
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Erreur de recherche: $e';
      });
    }
  }

  /// Recherche manuelle
  Future<void> _manualSearch() async {
    final controller = TextEditingController();

    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recherche manuelle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Titre, auteur ou ISBN',
            hintText: 'Ex: Harry Potter Rowling',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );

    if (query != null && query.isNotEmpty) {
      // Vérifier si c'est un ISBN
      final cleanQuery = query.replaceAll(RegExp(r'[\s\-]'), '');
      if (cleanQuery.length == 13 &&
          (cleanQuery.startsWith('978') || cleanQuery.startsWith('979'))) {
        await _searchByISBN(cleanQuery);
      } else if (cleanQuery.length == 10 && RegExp(r'^\d{9}[\dXx]$').hasMatch(cleanQuery)) {
        await _searchByISBN(cleanQuery);
      } else {
        await _searchOnGoogleBooks(query);
      }
    }
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
            ? 'Scanner ISBN'
            : 'Scanner couverture'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _manualSearch,
            tooltip: 'Recherche manuelle',
          ),
        ],
      ),
      body: Column(
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
                      'Code-barres',
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
                      'Couverture',
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
                              const Text('Scanner en pause',
                                  style: TextStyle(color: Colors.white54)),
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
                          Text('Pointez la caméra vers le code-barres ISBN',
                              style: TextStyle(color: isDark ? Colors.white70 : null)),
                          Text('(au dos du livre, commence par 978 ou 979)',
                              style: TextStyle(color: isDark ? Colors.white70 : null)),
                          const SizedBox(height: 8),
                          Text('Pas de code-barres ? Utilisez l\'onglet "Couverture"',
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
                  label: const Text('Réessayer'),
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Recherche en cours...'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Builder(
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
                          Text('Scan de couverture',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : null,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('1. Photographiez la couverture du livre',
                          style: TextStyle(color: isDark ? Colors.white70 : null)),
                      Text('2. L\'OCR détecte le titre et l\'auteur',
                          style: TextStyle(color: isDark ? Colors.white70 : null)),
                      Text('3. Recherche automatique sur Google Books',
                          style: TextStyle(color: isDark ? Colors.white70 : null)),
                      const SizedBox(height: 8),
                      Text('Astuce: si l\'ISBN est visible, il sera détecté automatiquement',
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

          const SizedBox(height: 20),

          // Boutons de capture
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _takePicture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Processing
          if (_isProcessing)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Analyse de la couverture...'),
                  ],
                ),
              ),
            ),

          // Messages
          _buildMessages(),

          // Loading recherche
          if (_isSearching && !_isProcessing)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Recherche en cours...'),
                  ],
                ),
              ),
            ),

          // Image preview
          if (_imageFile != null && !_isProcessing) ...[
            const SizedBox(height: 20),
            const Text('Couverture scannée:',
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
              title: const Text('Texte détecté'),
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
              const Text(
                'Résultats:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

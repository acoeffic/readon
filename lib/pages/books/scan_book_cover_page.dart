// lib/pages/books/scan_book_cover_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/ocr_service.dart';
import '../../services/google_books_service.dart';

class ScanBookCoverPage extends StatefulWidget {
  const ScanBookCoverPage({super.key});

  @override
  State<ScanBookCoverPage> createState() => _ScanBookCoverPageState();
}

class _ScanBookCoverPageState extends State<ScanBookCoverPage> {
  final OCRService _ocrService = OCRService();
  final GoogleBooksService _googleBooksService = GoogleBooksService();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  String? _extractedText;
  List<GoogleBook> _searchResults = [];
  bool _isProcessing = false;
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

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

  Future<void> _processImage(XFile photo) async {
    setState(() {
      _imageFile = photo;
      _isProcessing = true;
      _errorMessage = null;
      _searchResults = [];
    });

    try {
      // 1. Extraire le texte de la couverture
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

      // 2. Rechercher sur Google Books
      await _searchOnGoogleBooks(text);
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur OCR: $e';
      });
    }
  }

  Future<void> _searchOnGoogleBooks(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // Nettoyer le query (prendre les premières lignes qui sont souvent le titre)
      final lines = query.split('\n').where((l) => l.trim().isNotEmpty).take(3);
      final searchQuery = lines.join(' ');
      
      final results = await _googleBooksService.searchBooks(searchQuery);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        setState(() {
          _errorMessage = 'Aucun livre trouvé. Essayez de rechercher manuellement.';
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Erreur de recherche: $e';
      });
    }
  }

  Future<void> _manualSearch() async {
    final controller = TextEditingController();
    
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recherche manuelle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Titre ou auteur',
            hintText: 'Ex: Harry Potter Rowling',
          ),
          autofocus: true,
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
      await _searchOnGoogleBooks(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner une couverture'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _manualSearch,
            tooltip: 'Recherche manuelle',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Comment ça marche', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('1. Photographiez la couverture du livre'),
                    Text('2. L\'OCR détecte le titre et l\'auteur'),
                    Text('3. Recherche automatique sur Google Books'),
                    Text('4. Sélectionnez votre livre dans les résultats'),
                  ],
                ),
              ),
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
                      backgroundColor: Colors.deepPurple,
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
                      backgroundColor: Colors.deepPurple.shade300,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Processing
            if (_isProcessing || _isSearching)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(_isProcessing ? 'Analyse de la couverture...' : 'Recherche en cours...'),
                    ],
                  ),
                ),
              ),
            
            // Error
            if (_errorMessage != null && !_isProcessing && !_isSearching)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: TextStyle(color: Colors.orange.shade900)),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Image preview
            if (_imageFile != null && !_isProcessing) ...[
              const SizedBox(height: 20),
              const Text('Couverture scannée:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(_imageFile!.path, height: 300, fit: BoxFit.contain)
                    : Image.file(File(_imageFile!.path), height: 300, fit: BoxFit.contain),
              ),
            ],
            
            // Texte extrait (debug)
            if (_extractedText != null && _extractedText!.isNotEmpty) ...[
              const SizedBox(height: 20),
              ExpansionTile(
                title: const Text('Texte détecté'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade100,
                    child: Text(_extractedText!, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
            
            // Résultats de recherche
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Résultats de recherche:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              ..._searchResults.map((book) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: book.coverUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                book.coverUrl!,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.book, size: 50),
                      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book.authorsString, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (book.publishedDate != null)
                            Text('${book.publishedDate}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.pop(context, book),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
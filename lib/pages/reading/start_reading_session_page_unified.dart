// lib/pages/reading/start_reading_session_page_unified.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/reading_session_service.dart';
import '../../services/ocr_service.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

class StartReadingSessionPageUnified extends StatefulWidget {
  final Book book;

  const StartReadingSessionPageUnified({
    super.key,
    required this.book,
  });

  @override
  State<StartReadingSessionPageUnified> createState() => _StartReadingSessionPageUnifiedState();
}

class _StartReadingSessionPageUnifiedState extends State<StartReadingSessionPageUnified> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final OCRService _ocrService = OCRService();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  int? _detectedPageNumber;
  bool _isProcessing = false;
  String? _errorMessage;
  int? _manualPageNumber;
  bool _isEditingPageNumber = false;
  final TextEditingController _pageNumberController = TextEditingController();

  @override
  void dispose() {
    _sessionService.dispose();
    _ocrService.dispose();
    _pageNumberController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      setState(() {
        _errorMessage = null;
        _detectedPageNumber = null;
      });

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
      setState(() {
        _errorMessage = null;
        _detectedPageNumber = null;
      });

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
    });

    try {
      final pageNumber = await _ocrService.extractPageNumber(photo.path);

      setState(() {
        _detectedPageNumber = pageNumber;
        _isProcessing = false;
      });

      if (pageNumber == null) {
        setState(() {
          _errorMessage = 'Numéro de page non détecté. Vous pouvez le saisir manuellement ci-dessous.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur OCR: $e';
      });
    }
  }

  void _enableEditMode() {
    setState(() {
      _isEditingPageNumber = true;
      _pageNumberController.text = (_detectedPageNumber ?? _manualPageNumber ?? '').toString();
    });
  }

  void _saveEditedPageNumber() {
    final newValue = int.tryParse(_pageNumberController.text);
    if (newValue != null && newValue > 0) {
      setState(() {
        _manualPageNumber = newValue;
        _detectedPageNumber = null; // Utiliser le numéro manuel au lieu du détecté
        _isEditingPageNumber = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Veuillez saisir un numéro de page valide.';
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditingPageNumber = false;
      _pageNumberController.clear();
    });
  }

  Future<void> _startSession() async {
    final pageNumber = _detectedPageNumber ?? _manualPageNumber;

    if (pageNumber == null) {
      setState(() {
        _errorMessage = 'Veuillez capturer une photo ou saisir un numéro de page.';
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final session = await _sessionService.startSession(
        bookId: widget.book.id.toString(),
        imagePath: _imageFile?.path,
        manualPageNumber: pageNumber,
      );

      if (!mounted) return;

      // Retourner la session à la page précédente
      Navigator.of(context).pop(session);

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Démarrer une lecture'),
        backgroundColor: AppColors.feedHeader,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Infos du livre
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CachedBookCover(
                      imageUrl: widget.book.coverUrl,
                      width: 60,
                      height: 90,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.book.author != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.book.author!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue.shade900.withValues(alpha: 0.3)
                  : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade300 : Colors.blue),
                        const SizedBox(width: 8),
                        Text('Instructions', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade200 : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('1. Photographiez la page où vous commencez',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
                    Text('2. Assurez-vous que le numéro de page est visible',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
                    Text('3. L\'OCR détectera automatiquement le numéro',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
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
                    label: const Text('Prendre Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.feedHeader,
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
                      backgroundColor: AppColors.feedHeader.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Processing indicator
            if (_isProcessing)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Analyse en cours...'),
                    ],
                  ),
                ),
              ),
            
            // Error message
            if (_errorMessage != null && !_isProcessing)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Image preview
            if (_imageFile != null && !_isProcessing) ...[
              const SizedBox(height: 20),
              const Text(
                'Photo capturée:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(_imageFile!.path, height: 200, fit: BoxFit.cover)
                    : Image.file(File(_imageFile!.path), height: 200, fit: BoxFit.cover),
              ),
            ],
            
            // Résultat détection
            if (_detectedPageNumber != null || _manualPageNumber != null) ...[
              const SizedBox(height: 20),
              Card(
                color: _manualPageNumber != null ? Colors.blue.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        _manualPageNumber != null ? Icons.edit : Icons.check_circle,
                        color: _manualPageNumber != null ? Colors.blue.shade700 : Colors.green.shade700,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _manualPageNumber != null ? 'Page corrigée:' : 'Page détectée:',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (!_isEditingPageNumber)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Page ${_detectedPageNumber ?? _manualPageNumber}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _manualPageNumber != null ? Colors.blue.shade700 : Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: _enableEditMode,
                              icon: const Icon(Icons.edit),
                              color: AppColors.feedHeader,
                              tooltip: 'Corriger le numéro',
                            ),
                          ],
                        ),
                      if (_isEditingPageNumber) ...[
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _pageNumberController,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Numéro de page',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _cancelEdit,
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _saveEditedPageNumber,
                              icon: const Icon(Icons.check),
                              label: const Text('Valider'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            
            // Saisie manuelle (toujours visible si pas de numéro détecté)
            if (_detectedPageNumber == null) ...[
              const SizedBox(height: 20),
              const Text(
                'Ou saisissez le numéro directement:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Numéro de page',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                onChanged: (value) {
                  setState(() {
                    _manualPageNumber = int.tryParse(value);
                  });
                },
              ),
            ],

            // Bouton confirmer (visible dès qu'on a un numéro de page)
            if (_detectedPageNumber != null || _manualPageNumber != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isProcessing ? null : _startSession,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Démarrer la session de lecture',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

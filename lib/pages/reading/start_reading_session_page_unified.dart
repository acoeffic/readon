// lib/pages/reading/start_reading_session_page_unified.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/reading_session_service.dart';
import '../../services/ocr_service.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';

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

  @override
  void dispose() {
    _sessionService.dispose();
    _ocrService.dispose();
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

  Future<void> _startSession() async {
    final pageNumber = _detectedPageNumber ?? _manualPageNumber;
    
    if (pageNumber == null) {
      setState(() {
        _errorMessage = 'Veuillez capturer une photo ou saisir un numéro de page manuellement.';
      });
      return;
    }

    if (_imageFile == null) {
      setState(() {
        _errorMessage = 'Veuillez prendre une photo de la page.';
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final session = await _sessionService.startSession(
        bookId: widget.book.id.toString(),
        imagePath: _imageFile!.path,
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
        backgroundColor: Colors.deepPurple,
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
                    if (widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.book.coverUrl!,
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 90,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.book, size: 30),
                            );
                          },
                        ),
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
                        Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('1. Photographiez la page où vous commencez'),
                    Text('2. Assurez-vous que le numéro de page est visible'),
                    Text('3. L\'OCR détectera automatiquement le numéro'),
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
            if (_detectedPageNumber != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 48),
                      const SizedBox(height: 12),
                      const Text('Page détectée:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        'Page $_detectedPageNumber',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Saisie manuelle
            if (_imageFile != null && _detectedPageNumber == null) ...[
              const SizedBox(height: 20),
              const Text(
                'Ou saisissez le numéro manuellement:',
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
            
            // Bouton confirmer
            if (_imageFile != null && (_detectedPageNumber != null || _manualPageNumber != null)) ...[
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
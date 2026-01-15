// lib/pages/reading/end_reading_session_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/reading_session_service.dart';
import '../../services/ocr_service.dart';
import '../../models/reading_session.dart';
import 'reading_session_summary_page.dart';

class EndReadingSessionPage extends StatefulWidget {
  final ReadingSession activeSession;

  const EndReadingSessionPage({
    super.key,
    required this.activeSession,
  });

  @override
  State<EndReadingSessionPage> createState() => _EndReadingSessionPageState();
}

class _EndReadingSessionPageState extends State<EndReadingSessionPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  int? _detectedPageNumber;
  bool _isProcessing = false;
  String? _errorMessage;
  int? _manualPageNumber;

  @override
  void dispose() {
    _sessionService.dispose();
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
      final ocrService = OCRService();
      final pageNumber = await ocrService.extractPageNumber(photo.path);

      setState(() {
        _detectedPageNumber = pageNumber;
        _isProcessing = false;
      });

      if (pageNumber == null) {
        setState(() {
          _errorMessage = 'Numéro de page non détecté. Saisissez-le manuellement.';
        });
      } else if (pageNumber < widget.activeSession.startPage) {
        setState(() {
          _errorMessage = 'La page de fin ($pageNumber) ne peut pas être avant la page de début (${widget.activeSession.startPage}).';
          _detectedPageNumber = null;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur OCR: $e';
      });
    }
  }

  Future<void> _endSession() async {
    final pageNumber = _detectedPageNumber ?? _manualPageNumber;
    
    if (pageNumber == null) {
      setState(() {
        _errorMessage = 'Veuillez capturer une photo ou saisir un numéro de page.';
      });
      return;
    }

    if (pageNumber < widget.activeSession.startPage) {
      setState(() {
        _errorMessage = 'La page de fin ne peut pas être avant la page de début.';
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
      final completedSession = await _sessionService.endSession(
        sessionId: widget.activeSession.id,
        imagePath: _imageFile!.path,
      );

      if (!mounted) return;

      // Naviguer vers la page de résumé
     Navigator.of(context).pop(completedSession); 
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  Future<void> _cancelSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la session'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette session de lecture ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _sessionService.cancelSession(widget.activeSession.id);
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDuration(DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminer la lecture'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: _cancelSession,
            tooltip: 'Annuler la session',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Infos session en cours
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Session en cours', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Commencée à la page ${widget.activeSession.startPage}'),
                    Text('Durée: ${_formatDuration(widget.activeSession.startTime)}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('1. Photographiez votre dernière page lue'),
                    Text('2. Assurez-vous que le numéro est visible'),
                    Text('3. Validez pour enregistrer votre progression'),
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
            
            // Processing
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
            
            // Error
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
                        child: Text(_errorMessage!, style: TextStyle(color: Colors.orange.shade900)),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Image preview
            if (_imageFile != null && !_isProcessing) ...[
              const SizedBox(height: 20),
              const Text('Photo capturée:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(_imageFile!.path, height: 200, fit: BoxFit.cover)
                    : Image.file(File(_imageFile!.path), height: 200, fit: BoxFit.cover),
              ),
            ],
            
            // Résultat
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
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pages lues: ${_detectedPageNumber! - widget.activeSession.startPage}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Saisie manuelle
            if (_imageFile != null && _detectedPageNumber == null) ...[
              const SizedBox(height: 20),
              const Text('Saisissez le numéro manuellement:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Numéro de page',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                  helperText: 'Page de début: ${widget.activeSession.startPage}',
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
                onPressed: _isProcessing ? null : _endSession,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Terminer la session',
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
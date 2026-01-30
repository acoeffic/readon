// lib/pages/reading/end_reading_session_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/reading_session_service.dart';
import '../../services/ocr_service.dart';
import '../../services/books_service.dart';
import '../../services/badges_service.dart';
import '../../services/streak_service.dart';
import '../../services/trophy_service.dart';
import '../../models/reading_session.dart';
import '../../models/reading_streak.dart';
import '../../models/trophy.dart';
import '../../widgets/badge_unlocked_dialog.dart';
import '../../widgets/trophy_card.dart';
import '../../models/book.dart';
import 'reading_session_summary_page.dart';
import 'book_completed_summary_page.dart';
import '../../theme/app_theme.dart';

class EndReadingSessionPage extends StatefulWidget {
  final ReadingSession activeSession;
  final Book? book; // Optionnel, pour la page de résumé

  const EndReadingSessionPage({
    super.key,
    required this.activeSession,
    this.book,
  });

  @override
  State<EndReadingSessionPage> createState() => _EndReadingSessionPageState();
}

class _EndReadingSessionPageState extends State<EndReadingSessionPage> {
  final ReadingSessionService _sessionService = ReadingSessionService();
  final BooksService _booksService = BooksService();
  final BadgesService _badgesService = BadgesService();
  final StreakService _streakService = StreakService();
  final TrophyService _trophyService = TrophyService();
  final ImagePicker _picker = ImagePicker();

  XFile? _imageFile;
  int? _detectedPageNumber;
  bool _isProcessing = false;
  String? _errorMessage;
  int? _manualPageNumber;
  bool _showFinishBookAnimation = false;
  bool _isEditingPageNumber = false;
  final TextEditingController _pageNumberController = TextEditingController();

  @override
  void dispose() {
    _sessionService.dispose();
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

  void _enableEditMode() {
    setState(() {
      _isEditingPageNumber = true;
      _pageNumberController.text = (_detectedPageNumber ?? _manualPageNumber ?? '').toString();
    });
  }

  void _saveEditedPageNumber() {
    final newValue = int.tryParse(_pageNumberController.text);
    if (newValue != null && newValue > 0) {
      if (newValue < widget.activeSession.startPage) {
        setState(() {
          _errorMessage = 'La page de fin ($newValue) ne peut pas être avant la page de début (${widget.activeSession.startPage}).';
        });
        return;
      }
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

    setState(() => _isProcessing = true);

    try {
      final completedSession = await _sessionService.endSession(
        sessionId: widget.activeSession.id,
        imagePath: _imageFile?.path,
        manualPageNumber: pageNumber,
      );

      if (!mounted) return;

      // Sélectionner le trophée contextuel
      final trophy = _trophyService.selectTrophy(completedSession);

      // Vérifier et attribuer les badges de streak (non bloquant)
      List<StreakBadgeLevel> newStreakBadges = [];
      try {
        newStreakBadges = await _streakService.checkAndAwardStreakBadges();
      } catch (e) {
        print('Erreur checkAndAwardStreakBadges (non bloquante): $e');
      }

      // Vérifier et attribuer les trophées débloquables (non bloquant)
      List<Trophy> newUnlockableTrophies = [];
      try {
        final streak = await _streakService.getUserStreak();
        final activeBookCount = await _getActiveBookCount();
        newUnlockableTrophies = await _trophyService.checkUnlockableTrophies(
          session: completedSession,
          currentStreak: streak.currentStreak,
          activeBookCount: activeBookCount,
        );
      } catch (e) {
        print('Erreur checkUnlockableTrophies (non bloquante): $e');
      }

      // Afficher les badges de streak débloqués
      if (newStreakBadges.isNotEmpty && mounted) {
        for (final badgeLevel in newStreakBadges) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _StreakBadgeDialog(badgeLevel: badgeLevel),
          );
        }
      }

      // Afficher les trophées débloquables nouvellement gagnés
      if (newUnlockableTrophies.isNotEmpty && mounted) {
        for (final t in newUnlockableTrophies) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => TrophyUnlockedDialog(trophy: t),
          );
        }
      }

      // Naviguer vers la page de résumé avec le trophée
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReadingSessionSummaryPage(
              session: completedSession,
              trophy: trophy,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  Future<int> _getActiveBookCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return 0;
      final response = await Supabase.instance.client
          .from('user_books')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'reading');
      return (response as List).length;
    } catch (e) {
      print('Erreur _getActiveBookCount: $e');
      return 0;
    }
  }

  Future<void> _finishBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('Terminer le livre'),
          ],
        ),
        content: const Text('Félicitations! Avez-vous terminé ce livre ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, terminé!'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Déclencher l'animation
      setState(() => _showFinishBookAnimation = true);

      // Attendre l'animation
      await Future.delayed(const Duration(milliseconds: 2000));

      setState(() => _isProcessing = true);

      try {
        final pageNumber = _detectedPageNumber ?? _manualPageNumber;

        // Terminer la session avec le livre marqué comme terminé
        final completedSession = await _sessionService.endSession(
          sessionId: widget.activeSession.id,
          imagePath: _imageFile?.path,
          manualPageNumber: pageNumber,
        );

        // Marquer le livre comme terminé
        final bookIdInt = int.tryParse(widget.activeSession.bookId);
        if (bookIdInt != null) {
          try {
            await _booksService.updateBookStatus(bookIdInt, 'finished');
          } catch (e) {
            print('Erreur updateBookStatus (non bloquante): $e');
          }
        }

        // Créer une activité spéciale pour le livre terminé
        try {
          await _createBookFinishedActivity(completedSession);
        } catch (e) {
          print('Erreur createBookFinishedActivity (non bloquante): $e');
        }

        // Sélectionner le trophée contextuel
        final trophy = _trophyService.selectTrophy(completedSession);

        // Vérifier et attribuer les badges (non bloquant)
        List<dynamic> newBadges = [];
        try {
          newBadges = await _badgesService.checkAndAwardBadges();
        } catch (e) {
          print('Erreur checkAndAwardBadges (non bloquante): $e');
        }

        // Vérifier et attribuer les badges de streak (non bloquant)
        List<dynamic> newStreakBadges = [];
        try {
          newStreakBadges = await _streakService.checkAndAwardStreakBadges();
        } catch (e) {
          print('Erreur checkAndAwardStreakBadges (non bloquante): $e');
        }

        // Vérifier et attribuer les trophées débloquables (non bloquant)
        List<Trophy> newUnlockableTrophies = [];
        try {
          final streak = await _streakService.getUserStreak();
          final activeBookCount = await _getActiveBookCount();
          newUnlockableTrophies = await _trophyService.checkUnlockableTrophies(
            session: completedSession,
            currentStreak: streak.currentStreak,
            activeBookCount: activeBookCount,
          );
        } catch (e) {
          print('Erreur checkUnlockableTrophies (non bloquante): $e');
        }

        if (!mounted) return;

        // Masquer l'animation de fin de livre
        setState(() => _showFinishBookAnimation = false);

        // Afficher les nouveaux badges débloqués
        if (newBadges.isNotEmpty) {
          for (final badge in newBadges) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => BadgeUnlockedDialog(badge: badge),
            );
          }
        }

        // Afficher les badges de streak débloqués
        if (newStreakBadges.isNotEmpty && mounted) {
          for (final badgeLevel in newStreakBadges) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _StreakBadgeDialog(badgeLevel: badgeLevel as StreakBadgeLevel),
            );
          }
        }

        // Afficher les trophées débloquables nouvellement gagnés
        if (newUnlockableTrophies.isNotEmpty && mounted) {
          for (final t in newUnlockableTrophies) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => TrophyUnlockedDialog(trophy: t),
            );
          }
        }

        // Récupérer le livre pour la page de résumé
        Book? book = widget.book;
        if (book == null && bookIdInt != null) {
          try {
            book = await _booksService.getBookById(bookIdInt);
          } catch (e) {
            print('Erreur récupération livre: $e');
          }
        }

        // Naviguer vers la page de résumé du livre terminé
        if (book != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BookCompletedSummaryPage(
                book: book!,
                lastSession: completedSession,
              ),
            ),
          );
        } else {
          // Fallback: page de résumé avec trophée
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ReadingSessionSummaryPage(
                session: completedSession,
                trophy: trophy,
              ),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _showFinishBookAnimation = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    }
  }

  Future<void> _createBookFinishedActivity(ReadingSession session) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Récupérer les informations du livre
      final bookIdInt = int.tryParse(session.bookId);
      if (bookIdInt == null) {
        print('Erreur: bookId invalide: ${session.bookId}');
        return;
      }
      final bookResponse = await Supabase.instance.client
          .from('books')
          .select('title, author, cover_url')
          .eq('id', bookIdInt)
          .maybeSingle();

      if (bookResponse == null) return;

      // Créer l'activité avec le flag book_finished
      await Supabase.instance.client.from('activities').insert({
        'author_id': userId,
        'type': 'book_finished',
        'payload': {
          'book_title': bookResponse['title'],
          'book_author': bookResponse['author'],
          'book_cover': bookResponse['cover_url'],
          'pages_read': session.pagesRead,
          'duration_minutes': session.durationMinutes,
          'start_page': session.startPage,
          'end_page': session.endPage,
          'book_finished': true,
        },
      });
    } catch (e) {
      print('Erreur _createBookFinishedActivity: $e');
      // Ne pas bloquer le flux si l'activité ne peut pas être créée
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
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: _cancelSession,
            tooltip: 'Annuler la session',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Infos session en cours
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
                        Icon(Icons.schedule, color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade300 : Colors.blue),
                        const SizedBox(width: 8),
                        Text('Session en cours', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade200 : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Commencée à la page ${widget.activeSession.startPage}',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
                    Text('Durée: ${_formatDuration(widget.activeSession.startTime)}',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.green.shade900.withValues(alpha: 0.3)
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade300 : Colors.green),
                        const SizedBox(width: 8),
                        Text('Instructions', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade200 : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('1. Photographiez votre dernière page lue',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
                    Text('2. Assurez-vous que le numéro est visible',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : null)),
                    Text('3. Validez pour enregistrer votre progression',
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
                        Column(
                          children: [
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
                                  color: AppColors.primary,
                                  tooltip: 'Corriger le numéro',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pages lues: ${(_detectedPageNumber ?? _manualPageNumber)! - widget.activeSession.startPage}',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                            decoration: InputDecoration(
                              labelText: 'Numéro de page',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.numbers),
                              helperText: 'Page de début: ${widget.activeSession.startPage}',
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
              const Text('Ou saisissez le numéro directement:', style: TextStyle(fontWeight: FontWeight.bold)),
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

            // Boutons confirmer (visibles dès qu'on a un numéro de page)
            if (_detectedPageNumber != null || _manualPageNumber != null) ...[
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
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _finishBook,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text(
                  'Terminer le livre',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
          ),
          // Animation de confetti
          if (_showFinishBookAnimation)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, value, child) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.scale(
                              scale: value,
                              child: const Icon(
                                Icons.celebration,
                                size: 120,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Opacity(
                              opacity: value,
                              child: const Text(
                                'Félicitations!',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Opacity(
                              opacity: value,
                              child: const Text(
                                'Livre terminé!',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget pour afficher le déblocage d'un badge de streak
class _StreakBadgeDialog extends StatefulWidget {
  final StreakBadgeLevel badgeLevel;

  const _StreakBadgeDialog({required this.badgeLevel});

  @override
  State<_StreakBadgeDialog> createState() => _StreakBadgeDialogState();
}

class _StreakBadgeDialogState extends State<_StreakBadgeDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Color _getBadgeColor() {
    try {
      final colorStr = widget.badgeLevel.color.replaceAll('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (e) {
      return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                final startX = 0.5 + (index % 5 - 2) * 0.15;
                final endX = startX + (index % 3 - 1) * 0.3;
                final endY = 0.8 + (index % 4) * 0.05;

                return Positioned(
                  left: MediaQuery.of(context).size.width *
                      (startX + (endX - startX) * _confettiController.value),
                  top: MediaQuery.of(context).size.height *
                      (-0.1 + endY * _confettiController.value),
                  child: Opacity(
                    opacity: 1.0 - _confettiController.value,
                    child: Text(
                      widget.badgeLevel.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenu
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: color, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        'Badge Streak!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Badge animé
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.2),
                        border: Border.all(
                          color: color,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.badgeLevel.icon,
                          style: const TextStyle(fontSize: 60),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nom du badge
                  Text(
                    widget.badgeLevel.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    widget.badgeLevel.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.badgeLevel.days} jour${widget.badgeLevel.days > 1 ? 's' : ''} consécutifs!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bouton
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Continuer!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
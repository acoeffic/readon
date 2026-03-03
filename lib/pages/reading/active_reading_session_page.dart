// lib/pages/reading/active_reading_session_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/reading_session.dart';
import '../../models/book.dart';
import '../../models/annotation_model.dart';
import '../../navigation/main_navigation.dart';
import '../../services/flow_service.dart';
import '../../services/annotation_service.dart';
import '../../services/ocr_service.dart';
import 'end_reading_session_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

class ActiveReadingSessionPage extends StatefulWidget {
  final ReadingSession activeSession;
  final Book book;

  const ActiveReadingSessionPage({
    super.key,
    required this.activeSession,
    required this.book,
  });

  @override
  State<ActiveReadingSessionPage> createState() =>
      _ActiveReadingSessionPageState();
}

class _ActiveReadingSessionPageState extends State<ActiveReadingSessionPage> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  Duration _totalPauseDuration = Duration.zero;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.activeSession.startTime);
    _startTimer();
    _loadStreak();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadStreak() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final flow = await FlowService().getFlowForUser(userId);
      if (mounted) {
        setState(() => _streakDays = flow);
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.activeSession.startTime) -
              _totalPauseDuration;
        });
      }
    });
  }

  void _togglePause() {
    setState(() {
      if (_isPaused) {
        if (_pauseStartTime != null) {
          _totalPauseDuration +=
              DateTime.now().difference(_pauseStartTime!);
          _pauseStartTime = null;
        }
        _isPaused = false;
      } else {
        _pauseStartTime = DateTime.now();
        _isPaused = true;
      }
    });
  }

  Future<void> _endSession() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EndReadingSessionPage(
          activeSession: widget.activeSession,
        ),
      ),
    );
  }

  Future<void> _cancelSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner la session'),
        content: const Text(
            'Voulez-vous vraiment abandonner cette session de lecture ?'),
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

    if (confirm == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la session'),
        content: const Text(
            'La session reste active. Vous pourrez la terminer plus tard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _showAnnotationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AnnotationBottomSheet(
        bookId: widget.book.id.toString(),
        sessionId: widget.activeSession.id,
        initialPage: widget.activeSession.startPage,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 60) return '${totalMinutes}min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h${mins.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsed.inSeconds % 60;
    final progressValue = seconds / 60.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8FB8A8), Color(0xFF6B9B8A)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAnnotationSheet,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.draw_outlined, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Header
                Row(
                  children: [
                    Text(
                      'SESSION EN COURS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz,
                          color: Colors.grey.shade600, size: 24),
                      onSelected: (value) {
                        if (value == 'abandon') _cancelSession();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'abandon',
                          child: Row(
                            children: [
                              Icon(Icons.close,
                                  color: Colors.red.shade400, size: 20),
                              const SizedBox(width: 8),
                              Text('Abandonner',
                                  style:
                                      TextStyle(color: Colors.red.shade400)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Book cover with play/pause overlay
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CachedBookCover(
                                imageUrl: widget.book.coverUrl,
                                width: 180,
                                height: 260,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: GestureDetector(
                                onTap: _togglePause,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Title + author
                        Text(
                          widget.book.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D2D2D),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.book.author != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.book.author!,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Duration card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DURÉE DE SESSION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          _formatDuration(_elapsed),
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2D2D2D),
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: CustomPaint(
                                  painter: _TimerRingPainter(
                                    progress: progressValue,
                                    trackColor: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    progressColor: AppColors.primary,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _isPaused
                                            ? Colors.grey.shade400
                                            : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Stats row
                        Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                label: 'Page de départ',
                                value: '${widget.activeSession.startPage}',
                                icon: Icons.menu_book_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoCard(
                                label: 'Série',
                                value: '$_streakDays jours',
                                icon: Icons.local_fire_department_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Slide to end button
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SlideToEndButton(onSlideComplete: _endSession),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Info card ────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide to end button ─────────────────────────────────────────────

class _SlideToEndButton extends StatefulWidget {
  final VoidCallback onSlideComplete;

  const _SlideToEndButton({required this.onSlideComplete});

  @override
  State<_SlideToEndButton> createState() => _SlideToEndButtonState();
}

class _SlideToEndButtonState extends State<_SlideToEndButton>
    with SingleTickerProviderStateMixin {
  static const _thumbSize = 56.0;
  static const _trackHeight = 64.0;
  static const _trackPadding = 4.0;
  static const _threshold = 0.80;

  double _dragPosition = 0;
  bool _completed = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    );
    _resetController.addListener(() {
      setState(() {
        _dragPosition = _dragPosition * (1 - _resetAnimation.value);
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_completed) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0,
          _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_completed) return;
    if (_dragPosition / _maxDrag >= _threshold) {
      setState(() {
        _completed = true;
        _dragPosition = _maxDrag;
      });
      widget.onSlideComplete();
    } else {
      _resetController.forward(from: 0);
    }
  }

  double get _maxDrag {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return 200;
    return renderBox.size.width - _thumbSize - _trackPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _maxDrag > 0 ? (_dragPosition / _maxDrag) : 0.0;

    return Container(
      height: _trackHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF3D6B5E),
        borderRadius: BorderRadius.circular(_trackHeight / 2),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Label
          Center(
            child: Opacity(
              opacity: (1 - progress * 1.5).clamp(0.0, 1.0),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 40),
                  Text(
                    'Terminer la session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),

          // Thumb
          Positioned(
            left: _trackPadding + _dragPosition,
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.stop_rounded,
                    color: Color(0xFF3D6B5E),
                    size: 28,
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

// ── Annotation bottom sheet ─────────────────────────────────────────

enum _AnnotationMode { text, photo }

class _AnnotationBottomSheet extends StatefulWidget {
  final String bookId;
  final String sessionId;
  final int initialPage;

  const _AnnotationBottomSheet({
    required this.bookId,
    required this.sessionId,
    required this.initialPage,
  });

  @override
  State<_AnnotationBottomSheet> createState() => _AnnotationBottomSheetState();
}

class _AnnotationBottomSheetState extends State<_AnnotationBottomSheet> {
  final _contentController = TextEditingController();
  final _pageController = TextEditingController();
  final _annotationService = AnnotationService();
  final _ocrService = OCRService();
  final _picker = ImagePicker();

  _AnnotationMode _mode = _AnnotationMode.text;
  XFile? _capturedImage;
  bool _isProcessingOcr = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController.text = widget.initialPage.toString();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _capturedImage = image;
      _isProcessingOcr = true;
    });

    try {
      final text = await _ocrService.extractAllText(image.path);
      if (mounted) {
        setState(() {
          _contentController.text = text;
          _isProcessingOcr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      String? imagePath;

      // Si mode photo, uploader l'image d'abord
      if (_mode == _AnnotationMode.photo && _capturedImage != null) {
        // Créer l'annotation pour obtenir l'ID
        final annotation = await _annotationService.createAnnotation(
          bookId: widget.bookId,
          sessionId: widget.sessionId,
          content: content,
          pageNumber: int.tryParse(_pageController.text),
          type: AnnotationType.photo,
        );

        // Uploader l'image puis enregistrer le chemin
        imagePath = await _annotationService.uploadAnnotationImage(
          annotation.id,
          _capturedImage!.path,
        );
        await Supabase.instance.client
            .from('annotations')
            .update({'image_path': imagePath})
            .eq('id', annotation.id);
      } else {
        await _annotationService.createAnnotation(
          bookId: widget.bookId,
          sessionId: widget.sessionId,
          content: content,
          pageNumber: int.tryParse(_pageController.text),
          type: AnnotationType.text,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annotation sauvegardée !')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Nouvelle annotation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 16),

                // Mode selector
                SegmentedButton<_AnnotationMode>(
                  segments: const [
                    ButtonSegment(
                      value: _AnnotationMode.text,
                      label: Text('Texte'),
                      icon: Icon(Icons.edit, size: 18),
                    ),
                    ButtonSegment(
                      value: _AnnotationMode.photo,
                      label: Text('Photo'),
                      icon: Icon(Icons.camera_alt, size: 18),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return const Color(0xFF2D2D2D);
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Photo mode: capture button + preview
                if (_mode == _AnnotationMode.photo) ...[
                  if (_capturedImage == null)
                    OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Prendre une photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else ...[
                    // Image preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_capturedImage!.path),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Retake button
                    TextButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reprendre la photo'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                  if (_isProcessingOcr) ...[
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Extraction du texte...'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Content text field
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _mode == _AnnotationMode.photo
                        ? 'Texte extrait (modifiable)...'
                        : 'Notez votre pensée, une citation...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Page number field
                TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Page',
                    prefixIcon:
                        const Icon(Icons.bookmark_outline, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sauvegarder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Timer ring painter ──────────────────────────────────────────────

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _TimerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const strokeWidth = 4.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// lib/pages/reading/active_reading_session_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/reading_session.dart';
import '../../models/book.dart';
import '../../models/annotation_model.dart';
import '../../navigation/main_navigation.dart';
import '../../services/flow_service.dart';
import '../../services/annotation_service.dart';
import '../../services/ai_service.dart';
import '../../services/ocr_service.dart';
import 'end_reading_session_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../l10n/app_localizations.dart';

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

class _ActiveReadingSessionPageState extends State<ActiveReadingSessionPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isPaused = false;
  DateTime? _pauseStartTime;
  Duration _totalPauseDuration = Duration.zero;
  int _streakDays = 0;
  List<Annotation> _sessionAnnotations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _elapsed = DateTime.now().difference(widget.activeSession.startTime);
    _startTimer();
    _loadStreak();
    _loadAnnotations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isPaused) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.activeSession.startTime) -
            _totalPauseDuration;
      });
    }
  }

  Future<void> _loadAnnotations() async {
    final annotations = await AnnotationService()
        .getAnnotationsForSession(widget.activeSession.id);
    if (mounted) {
      setState(() => _sessionAnnotations = annotations);
    }
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
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.abandonSessionTitle),
        content: Text(l.abandonSessionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.yes, style: const TextStyle(color: Colors.red)),
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
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.leaveSessionTitle),
        content: Text(l.leaveSessionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.stay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.leave),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _showAnnotationSheet() async {
    await showModalBottomSheet(
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
    _loadAnnotations();
  }

  String _getTimeAgo(DateTime dateTime, AppLocalizations l) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return l.timeAgoDays(diff.inDays);
    if (diff.inHours > 0) return l.timeAgoHours(diff.inHours);
    return l.timeAgoMinutes(diff.inMinutes);
  }

  String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 60) return '${totalMinutes}min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h${mins.toString().padLeft(2, '0')}';
  }

  Widget _buildAnnotationTile(Annotation annotation, AppLocalizations l) {
    final timeAgo = _getTimeAgo(annotation.createdAt, l);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                annotation.type == AnnotationType.photo
                    ? Icons.camera_alt
                    : annotation.type == AnnotationType.voice
                        ? Icons.mic
                        : Icons.edit_note,
                color: const Color(0xFFE6A817),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  annotation.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (annotation.pageNumber != null) ...[
                      Text(
                        'p.${annotation.pageNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllAnnotations() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(
              l.sessionAnnotations,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessionAnnotations.length,
                itemBuilder: (context, index) =>
                    _buildAnnotationTile(_sessionAnnotations[index], l),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                      l.sessionInProgress,
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
                              Text(l.abandonButton,
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
                                      l.sessionDuration,
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
                                label: l.startPage,
                                value: '${widget.activeSession.startPage}',
                                icon: Icons.menu_book_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoCard(
                                label: l.streakLabel,
                                value: l.streakDays(_streakDays),
                                icon: Icons.local_fire_department_rounded,
                              ),
                            ),
                          ],
                        ),

                        // Session annotations card
                        if (_sessionAnnotations.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      l.sessionAnnotations,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D2D2D),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_sessionAnnotations.length > 2)
                                      GestureDetector(
                                        onTap: () => _showAllAnnotations(),
                                        child: Text(
                                          l.seeAll,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._sessionAnnotations.take(3).map(
                                  (annotation) => _buildAnnotationTile(annotation, l),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Bottom bar: Annoter + Pause + Stop
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      // Annoter button
                      Expanded(
                        child: GestureDetector(
                          onTap: _showAnnotationSheet,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F0E8),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.draw_outlined, color: const Color(0xFF2D2D2D), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  l.annotateButton,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                                if (_sessionAnnotations.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_sessionAnnotations.length}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Pause button
                      GestureDetector(
                        onTap: _togglePause,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3D6B5E),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Stop button
                      GestureDetector(
                        onTap: _endSession,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE4E4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.stop_rounded,
                            color: Colors.red.shade400,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
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

// ── Annotation bottom sheet ─────────────────────────────────────────

enum _AnnotationMode { text, photo, voice }

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

  // Voice recording state
  AudioRecorder? _audioRecorder;
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  bool _isTranscribing = false;
  AudioPlayer? _audioPlayer;
  bool _isPlayingPreview = false;
  static const _maxRecordingDuration = Duration(minutes: 3);

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
    _recordingTimer?.cancel();
    _audioRecorder?.dispose();
    _audioPlayer?.dispose();
    // Cleanup temp recording file if not saved
    if (_recordingPath != null) {
      try { File(_recordingPath!).deleteSync(); } catch (_) {}
    }
    super.dispose();
  }

  // ── Voice recording methods ──

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.micPermissionRequired)),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    _recordingPath = '${tempDir.path}/voice_annotation_${DateTime.now().millisecondsSinceEpoch}.m4a';

    _audioRecorder = AudioRecorder();
    await _audioRecorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordingPath!,
    );

    _recordingStartTime = DateTime.now();
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final newDuration = DateTime.now().difference(_recordingStartTime!);
      if (newDuration >= _maxRecordingDuration) {
        _stopRecording();
        return;
      }
      setState(() => _recordingDuration = newDuration);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final path = await _audioRecorder?.stop();
    _audioRecorder?.dispose();
    _audioRecorder = null;

    if (path != null && mounted) {
      setState(() {
        _isRecording = false;
        _hasRecording = true;
        _recordingPath = path;
      });
    }
  }

  void _retakeRecording() {
    _audioPlayer?.stop();
    if (_recordingPath != null) {
      try { File(_recordingPath!).deleteSync(); } catch (_) {}
    }
    setState(() {
      _hasRecording = false;
      _isRecording = false;
      _isPlayingPreview = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
      _contentController.clear();
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlayingPreview) {
      await _audioPlayer?.stop();
      setState(() => _isPlayingPreview = false);
    } else {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setFilePath(_recordingPath!);
      _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _isPlayingPreview = false);
        }
      });
      await _audioPlayer!.play();
      setState(() => _isPlayingPreview = true);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
    final l = AppLocalizations.of(context);
    // Validation selon le mode
    if (_mode == _AnnotationMode.voice) {
      if (!_hasRecording || _recordingPath == null) return;
    } else {
      final content = _contentController.text.trim();
      if (content.isEmpty) return;
    }

    setState(() => _isSaving = true);

    try {
      if (_mode == _AnnotationMode.voice) {
        // 1. Créer l'annotation avec placeholder
        final content = _contentController.text.trim();
        final annotation = await _annotationService.createAnnotation(
          bookId: widget.bookId,
          sessionId: widget.sessionId,
          content: content.isNotEmpty ? content : '...',
          pageNumber: int.tryParse(_pageController.text),
          type: AnnotationType.voice,
        );

        // 2. Uploader l'audio
        final audioPath = await _annotationService.uploadAnnotationAudio(
          annotation.id,
          _recordingPath!,
        );

        // 3. Sauvegarder audio_path
        await Supabase.instance.client
            .from('annotations')
            .update({'audio_path': audioPath})
            .eq('id', annotation.id);

        // 4. Transcrire si pas de contenu manuel
        if (content.isEmpty) {
          setState(() => _isTranscribing = true);
          try {
            final aiService = AiService();
            await aiService.transcribeAudio(annotation.id);
          } catch (e) {
            debugPrint('Transcription failed: $e');
          }
        }

        // Don't delete the temp file — it was uploaded successfully
        _recordingPath = null;

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.voiceAnnotationSaved)),
          );
        }
      } else if (_mode == _AnnotationMode.photo && _capturedImage != null) {
        final content = _contentController.text.trim();
        final annotation = await _annotationService.createAnnotation(
          bookId: widget.bookId,
          sessionId: widget.sessionId,
          content: content,
          pageNumber: int.tryParse(_pageController.text),
          type: AnnotationType.photo,
        );

        final imagePath = await _annotationService.uploadAnnotationImage(
          annotation.id,
          _capturedImage!.path,
        );
        await Supabase.instance.client
            .from('annotations')
            .update({'image_path': imagePath})
            .eq('id', annotation.id);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.annotationSaved)),
          );
        }
      } else {
        await _annotationService.createAnnotation(
          bookId: widget.bookId,
          sessionId: widget.sessionId,
          content: _contentController.text.trim(),
          pageNumber: int.tryParse(_pageController.text),
          type: AnnotationType.text,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.annotationSaved)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isTranscribing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorCapture(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                Text(
                  l.newAnnotation,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 16),

                // Mode selector
                SegmentedButton<_AnnotationMode>(
                  segments: [
                    ButtonSegment(
                      value: _AnnotationMode.text,
                      label: Text(l.annotationText),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                    ButtonSegment(
                      value: _AnnotationMode.photo,
                      label: Text(l.annotationPhoto),
                      icon: const Icon(Icons.camera_alt, size: 18),
                    ),
                    ButtonSegment(
                      value: _AnnotationMode.voice,
                      label: Text(l.annotationVoice),
                      icon: const Icon(Icons.mic, size: 18),
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
                      label: Text(l.retakePhoto),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                  if (_isProcessingOcr) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(l.extractingText),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Voice mode: recording controls
                if (_mode == _AnnotationMode.voice) ...[
                  if (!_hasRecording && !_isRecording)
                    // Initial state: record button
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _startRecording,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.mic, color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.tapToRecord,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else if (_isRecording)
                    // Recording in progress
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _formatDuration(_recordingDuration),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(l.recordingInProgress, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _stopRecording,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stop, color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_hasRecording) ...[
                    // Review state: playback + retake
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _togglePlayback,
                          icon: Icon(
                            _isPlayingPreview ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _retakeRecording,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(l.retakeRecording),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        ),
                      ],
                    ),
                    if (_isTranscribing) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text(l.transcriptionInProgress),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                ],

                // Content text field (hidden in voice mode until recording is done)
                if (_mode != _AnnotationMode.voice || _hasRecording) ...[
                  TextField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _mode == _AnnotationMode.photo
                          ? l.hintExtractedText
                          : _mode == _AnnotationMode.voice
                              ? l.hintTranscription
                              : l.hintAnnotation,
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
                ],

                // Page number field
                TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: l.pageHint,
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
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            if (_isTranscribing) ...[
                              const SizedBox(width: 8),
                              Text(l.transcribing, style: const TextStyle(color: Colors.white)),
                            ],
                          ],
                        )
                      : Text(
                          l.save,
                          style: const TextStyle(
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

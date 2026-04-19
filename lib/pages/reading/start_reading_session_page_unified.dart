// lib/pages/reading/start_reading_session_page_unified.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/reading_session_service.dart';
import '../../services/ocr_service.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import '../../providers/connectivity_provider.dart';
import 'active_reading_session_page.dart';

const _kBgColor = Color(0xFFFAF3E8);
const _kSageGreen = Color(0xFF6B988D);
const _kGold = Color(0xFFC6A85A);
const _kFallbackHeroColor = Color(0xFF2a3a5a);
const _kBackBtnColor = Color(0xFFF0E8D8);

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
  final TextEditingController _manualPageController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();

  ReadingSession? _activeSession;
  int? _lastPage;
  String? _readingFor;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
    _loadBookStats();
  }

  Future<void> _loadBookStats() async {
    try {
      final stats = await _sessionService.getBookStats(widget.book.id.toString());
      if (mounted && stats.currentPage != null) {
        setState(() => _lastPage = stats.currentPage);
      }
    } catch (_) {}
  }

  Future<void> _checkActiveSession() async {
    try {
      final session = await _sessionService.getActiveSession(widget.book.id.toString());
      if (mounted && session != null) {
        setState(() => _activeSession = session);
      }
    } catch (_) {}
  }

  void _resumeActiveSession() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ActiveReadingSessionPage(
          activeSession: _activeSession!,
          book: widget.book,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionService.dispose();
    _ocrService.dispose();
    _pageNumberController.dispose();
    _manualPageController.dispose();
    _pageFocusNode.dispose();
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
        _errorMessage = AppLocalizations.of(context).errorCapture(e.toString());
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
        _errorMessage = AppLocalizations.of(context).errorSelection(e.toString());
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
        if (pageNumber != null) {
          _manualPageController.text = pageNumber.toString();
          _manualPageNumber = pageNumber;
        }
      });

      if (pageNumber == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).pageNotDetectedManual;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = AppLocalizations.of(context).ocrError(e.toString());
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
        _detectedPageNumber = null;
        _isEditingPageNumber = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = AppLocalizations.of(context).invalidPageNumber;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditingPageNumber = false;
      _pageNumberController.clear();
    });
  }

  static const List<String> _readingForKeys = [
    'myself', 'daughter', 'son', 'partner', 'friend',
    'mother', 'father', 'grandmother', 'grandfather', 'other',
  ];

  String _readingForEmoji(String key) {
    switch (key) {
      case 'myself': return '\uD83D\uDCD6';
      case 'daughter': return '\uD83D\uDC67';
      case 'son': return '\uD83D\uDC66';
      case 'friend': return '\uD83E\uDDD1\u200D\uD83E\uDD1D\u200D\uD83E\uDDD1';
      case 'grandmother': return '\uD83D\uDC75';
      case 'grandfather': return '\uD83D\uDC74';
      case 'father': return '\uD83D\uDC68';
      case 'mother': return '\uD83D\uDC69';
      case 'partner': return '\u2764\uFE0F';
      default: return '\u2728';
    }
  }

  String _readingForLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'myself': return l.readingForJustMe;
      case 'daughter': return l.readingForDaughter;
      case 'son': return l.readingForSon;
      case 'friend': return l.readingForFriend;
      case 'grandmother': return l.readingForGrandmother;
      case 'grandfather': return l.readingForGrandfather;
      case 'father': return l.readingForFather;
      case 'mother': return l.readingForMother;
      case 'partner': return l.readingForPartner;
      default: return l.readingForOther;
    }
  }

  Future<void> _openReadingForPicker() async {
    final l = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final current = _readingFor ?? 'myself';
        return Container(
          decoration: const BoxDecoration(
            color: _kBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBDB5A8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l.readingForLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: _kSageGreen,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _readingForKeys.map((key) {
                      final isSelected = key == current;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(ctx).pop(key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _kSageGreen.withValues(alpha: 0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? _kSageGreen
                                      : const Color(0xFFE2DDD5),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _readingForEmoji(key),
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _readingForLabel(l, key),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      color: _kSageGreen,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _readingFor = selected);
    }
  }

  Future<void> _startSession() async {
    final pageNumber = _detectedPageNumber ?? _manualPageNumber;

    if (pageNumber == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).captureOrEnterPage;
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final isOffline = !Provider.of<ConnectivityProvider>(context, listen: false).isOnline;

      final session = await _sessionService.startSession(
        bookId: widget.book.id.toString(),
        imagePath: _imageFile?.path,
        manualPageNumber: pageNumber,
        offlineMode: isOffline,
        readingFor: _readingFor == 'myself' ? null : _readingFor,
      );

      if (!mounted) return;

      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionSavedOffline),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }

      Navigator.of(context).pop(session);

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  Future<void> _startFromLastPage() async {
    if (_lastPage == null) return;

    setState(() => _isProcessing = true);

    try {
      final isOffline = !Provider.of<ConnectivityProvider>(context, listen: false).isOnline;

      final session = await _sessionService.startSession(
        bookId: widget.book.id.toString(),
        manualPageNumber: _lastPage!,
        offlineMode: isOffline,
        readingFor: _readingFor == 'myself' ? null : _readingFor,
      );

      if (!mounted) return;

      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionSavedOffline),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }

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
    final l = AppLocalizations.of(context);
    final book = widget.book;
    final totalPages = book.pageCount;
    final currentPage = _lastPage ?? 0;
    final progress = (totalPages != null && totalPages > 0)
        ? (currentPage / totalPages).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _BackButton(onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.newSessionSubtitle,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: _kSageGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.startSessionTitle,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Active session banner ──
                if (_activeSession != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kSageGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kSageGreen.withValues(alpha: 0.25)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.play_circle_fill, color: _kSageGreen, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.sessionAlreadyActive,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.startPagePrefix(_activeSession!.startPage),
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF6A6A6A),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _resumeActiveSession,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: Text(l.resumeSession),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kSageGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_activeSession != null)
                  const SizedBox(height: 16),

                // ── Book hero card ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _kFallbackHeroColor,
                          _kFallbackHeroColor.withValues(alpha: 0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kFallbackHeroColor.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Cover thumbnail
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: book.coverUrl != null
                                    ? CachedBookCover(
                                        imageUrl: book.coverUrl,
                                        isbn: book.isbn,
                                        googleId: book.googleId,
                                        title: book.title,
                                        author: book.author,
                                        width: 72,
                                        height: 108,
                                        borderRadius: BorderRadius.circular(12),
                                      )
                                    : Container(
                                        width: 72,
                                        height: 108,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '📖',
                                            style: TextStyle(fontSize: 32),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (book.author != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      book.author!,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (totalPages != null && totalPages > 0) ...[
                                    const SizedBox(height: 12),
                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                                        valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                                        minHeight: 5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l.pagesProgress(currentPage, totalPages),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: _kGold.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Last session badge
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _lastPage != null
                                ? l.lastSessionPage(_lastPage!)
                                : l.noPreviousSession,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Reading for dropdown ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.readingForLabel,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: _kSageGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _openReadingForPicker,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2DDD5),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _readingForEmoji(_readingFor ?? 'myself'),
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _readingForLabel(l, _readingFor ?? 'myself'),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _kSageGreen,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Page input section ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.whatPageAreYouAt,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: _kSageGreen,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Large page input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _pageFocusNode.hasFocus
                                ? _kSageGreen
                                : const Color(0xFFE2DDD5),
                            width: _pageFocusNode.hasFocus ? 2 : 1.5,
                          ),
                          boxShadow: _pageFocusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: _kSageGreen.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: TextField(
                          key: const ValueKey('manual_page_input'),
                          controller: _manualPageController,
                          focusNode: _pageFocusNode,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          cursorColor: _kSageGreen,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                          decoration: InputDecoration(
                            hintText: _lastPage?.toString() ?? '1',
                            hintStyle: GoogleFonts.cormorantGaramond(
                              fontSize: 36,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFBDB5A8),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _manualPageNumber = int.tryParse(value);
                              _detectedPageNumber = null;
                            });
                          },
                          onTap: () => setState(() {}),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Scan buttons
                      Row(
                        children: [
                          Expanded(
                            child: _DashedButton(
                              label: '📷  ${l.scanPageBtn}',
                              onTap: _isProcessing ? null : _takePicture,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DashedButton(
                              label: '🖼️  ${l.galleryPageBtn}',
                              onTap: _isProcessing ? null : _pickFromGallery,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Processing indicator ──
                if (_isProcessing) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(_kSageGreen),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l.analyzing,
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF6A6A6A),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Error message ──
                if (_errorMessage != null && !_isProcessing) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.dmSans(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Image preview (when OCR captured) ──
                if (_imageFile != null && !_isProcessing) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? Image.network(_imageFile!.path, height: 160, width: double.infinity, fit: BoxFit.cover)
                          : Image.file(File(_imageFile!.path), height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                ],

                // ── Detected page result ──
                if (_detectedPageNumber != null && !_isEditingPageNumber) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kSageGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kSageGreen.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: _kSageGreen, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${l.pageDetected} $_detectedPageNumber',
                              style: GoogleFonts.dmSans(
                                color: _kSageGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _enableEditMode,
                            child: Icon(Icons.edit, color: _kSageGreen, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Edit mode for detected page ──
                if (_isEditingPageNumber) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kSageGreen.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: _pageNumberController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              cursorColor: _kSageGreen,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                              ),
                              decoration: InputDecoration(
                                labelText: l.pageNumberLabel,
                                labelStyle: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: const Color(0xFF6A6A6A),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2DDD5)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2DDD5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: _kSageGreen, width: 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _cancelEdit,
                                child: Text(
                                  l.cancel,
                                  style: GoogleFonts.dmSans(color: const Color(0xFF6A6A6A)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _saveEditedPageNumber,
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(l.validate),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kSageGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── CTA Button ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [_kSageGreen, Color(0xFF5A8A7E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kSageGreen.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isProcessing ? null : _startSession,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    '${l.launchSessionBtn} 📖',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // "Continue from page X" link
                if (_lastPage != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: _isProcessing ? null : _startFromLastPage,
                      child: Text(
                        l.continueFromPage(_lastPage!),
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: _kSageGreen,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: _kSageGreen.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _kBackBtnColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: Color(0xFF3A3A3A),
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DashedButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCBC4B8),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          color: Colors.white.withValues(alpha: 0.5),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6A6A6A),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/reading_session.dart';
import '../../features/wrapped/share/share_format.dart';
import '../../theme/app_theme.dart';
import 'session_share_card.dart';

// ==========================================================================
// Service
// ==========================================================================

/// Handles screenshot capture and per-destination sharing of a session card.
class SessionShareService {
  final _screenshotController = ScreenshotController();

  /// Capture the [SessionShareCard] as a high-res PNG.
  Future<Uint8List?> captureCard({
    required ReadingSession session,
    required String bookTitle,
    required String? bookAuthor,
    required ShareFormat format,
  }) async {
    final card = SessionShareCard(
      session: session,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      format: format,
    );
    return _screenshotController.captureFromWidget(
      card,
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 200),
    );
  }

  /// Execute the share action for a specific [destination].
  Future<SessionShareResult> shareToDestination({
    required Uint8List imageBytes,
    required ShareDestination destination,
    required ReadingSession session,
  }) async {
    // Save to gallery
    final galleryResult = await ImageGallerySaverPlus.saveImage(
      imageBytes,
      name: 'readon_session_${session.id}_${destination.name}',
    );
    final saved =
        galleryResult != null && (galleryResult['isSuccess'] == true);

    if (destination == ShareDestination.saveToGallery) {
      return saved
          ? SessionShareResult.savedToGallery
          : SessionShareResult.error;
    }

    // Try deep-linking into the target app
    final scheme = destination.urlScheme;
    if (scheme != null) {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return SessionShareResult.openedApp;
      }
    }

    // App not installed — fall back to native share sheet
    final file = await _saveTempFile(imageBytes, session.id);
    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          'Je viens de lire ${session.pagesRead} pages \uD83D\uDCDA #ReadOn',
    );
    return SessionShareResult.sharedGeneric;
  }

  Future<File> _saveTempFile(Uint8List bytes, String sessionId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/readon_session_$sessionId.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}

/// Outcome of a share action.
enum SessionShareResult {
  sharedGeneric,
  openedApp,
  savedToGallery,
  error,
}

// ==========================================================================
// Bottom sheet
// ==========================================================================

/// Shows the session share bottom sheet with destination choices.
Future<void> showSessionShareSheet({
  required BuildContext context,
  required ReadingSession session,
  required String bookTitle,
  required String? bookAuthor,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SessionShareSheet(
      session: session,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
    ),
  );
}

class _SessionShareSheet extends StatefulWidget {
  final ReadingSession session;
  final String bookTitle;
  final String? bookAuthor;

  const _SessionShareSheet({
    required this.session,
    required this.bookTitle,
    required this.bookAuthor,
  });

  @override
  State<_SessionShareSheet> createState() => _SessionShareSheetState();
}

class _SessionShareSheetState extends State<_SessionShareSheet> {
  final _service = SessionShareService();
  ShareDestination? _loadingDestination;

  Future<void> _onDestinationTap(ShareDestination destination) async {
    if (_loadingDestination != null) return;
    setState(() => _loadingDestination = destination);

    try {
      final bytes = await _service.captureCard(
        session: widget.session,
        bookTitle: widget.bookTitle,
        bookAuthor: widget.bookAuthor,
        format: destination.format,
      );

      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        setState(() => _loadingDestination = null);
        _showSnackBar("Impossible de generer l'image");
        return;
      }

      final result = await _service.shareToDestination(
        imageBytes: bytes,
        destination: destination,
        session: widget.session,
      );

      if (!mounted) return;

      switch (result) {
        case SessionShareResult.savedToGallery:
          Navigator.pop(context);
          _showSnackBar('Image sauvegardee \u2713');
        case SessionShareResult.openedApp:
          Navigator.pop(context);
          _showSnackBar(
              'Image sauvegardee — ouvre ${destination.label}');
        case SessionShareResult.sharedGeneric:
          setState(() => _loadingDestination = null);
          Navigator.pop(context);
        case SessionShareResult.error:
          setState(() => _loadingDestination = null);
          _showSnackBar('Erreur lors du partage');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDestination = null);
        _showSnackBar('Erreur : $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F1A),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Partage ta session \uD83D\uDCDA',
            style: GoogleFonts.libreBaskerville(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Choisis ou partager',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 28),

          // Destination list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: ShareDestination.values.map((dest) {
                return _DestinationTile(
                  destination: dest,
                  isLoading: _loadingDestination == dest,
                  enabled: _loadingDestination == null,
                  onTap: () => _onDestinationTap(dest),
                );
              }).toList(),
            ),
          ),

          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }
}

// ==========================================================================
// Destination tile widget
// ==========================================================================

class _DestinationTile extends StatelessWidget {
  final ShareDestination destination;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _DestinationTile({
    required this.destination,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: destination.brandColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: FaIcon(
                  destination.iconData,
                  size: 20,
                  color: destination.brandColor,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Label
            Expanded(
              child: Text(
                destination.label,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

            // Chevron or loader
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

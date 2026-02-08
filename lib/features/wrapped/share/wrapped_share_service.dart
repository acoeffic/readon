import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../yearly/yearly_wrapped_data.dart';
import '../yearly/widgets/yearly_animations.dart';
import 'share_format.dart';
import 'wrapped_share_card.dart';

// ==========================================================================
// Service
// ==========================================================================

/// Handles screenshot capture and per-destination sharing of the Wrapped card.
class WrappedShareService {
  final _screenshotController = ScreenshotController();

  /// Capture the [WrappedShareCard] as a high-res PNG.
  Future<Uint8List?> captureCard({
    required YearlyWrappedData data,
    required ShareFormat format,
  }) async {
    final card = WrappedShareCard(data: data, format: format);
    return _screenshotController.captureFromWidget(
      card,
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 200),
    );
  }

  /// Execute the share action for a specific [destination].
  ///
  /// Pattern for social apps:
  ///   1. Save image to gallery (so it's accessible from the target app)
  ///   2. Try opening the app via its URL scheme (deep link)
  ///   3. If app not installed → fall back to native share sheet
  ///
  /// For [ShareDestination.saveToGallery] → just save, no app opening.
  Future<ShareResult> shareToDestination({
    required Uint8List imageBytes,
    required ShareDestination destination,
    required int year,
  }) async {
    // Save to gallery — needed for all destinations
    final galleryResult = await ImageGallerySaverPlus.saveImage(
      imageBytes,
      name: 'readon_wrapped_${year}_${destination.name}',
    );
    final saved = galleryResult != null && (galleryResult['isSuccess'] == true);

    if (destination == ShareDestination.saveToGallery) {
      return saved ? ShareResult.savedToGallery : ShareResult.error;
    }

    // Try deep-linking into the target app
    final scheme = destination.urlScheme;
    if (scheme != null) {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return ShareResult.openedApp;
      }
    }

    // App not installed — fall back to native share sheet
    final file = await _saveTempFile(imageBytes, destination.format, year);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Mon annee de lecture $year \uD83D\uDCDA\u2728 #ReadOnWrapped',
    );
    return ShareResult.sharedGeneric;
  }

  Future<File> _saveTempFile(
    Uint8List bytes,
    ShareFormat format,
    int year,
  ) async {
    final dir = await getTemporaryDirectory();
    final name = 'readon_wrapped_${year}_${format.name}.png';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }
}

/// Outcome of a share action.
enum ShareResult {
  /// Image was shared via the native share sheet.
  sharedGeneric,

  /// An external app (e.g. Instagram) was opened after saving the image.
  openedApp,

  /// Image was saved to the device gallery.
  savedToGallery,

  /// Something went wrong.
  error,
}

// ==========================================================================
// Bottom sheet — called from slide_final.dart
// ==========================================================================

/// Shows the share bottom sheet with destination choices.
Future<void> showWrappedShareSheet({
  required BuildContext context,
  required YearlyWrappedData data,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WrappedShareSheet(data: data),
  );
}

class _WrappedShareSheet extends StatefulWidget {
  final YearlyWrappedData data;
  const _WrappedShareSheet({required this.data});

  @override
  State<_WrappedShareSheet> createState() => _WrappedShareSheetState();
}

class _WrappedShareSheetState extends State<_WrappedShareSheet> {
  final _service = WrappedShareService();
  ShareDestination? _loadingDestination;

  Future<void> _onDestinationTap(ShareDestination destination) async {
    if (_loadingDestination != null) return;
    setState(() => _loadingDestination = destination);

    try {
      // 1. Capture the card in the right format for this destination
      final bytes = await _service.captureCard(
        data: widget.data,
        format: destination.format,
      );

      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        setState(() => _loadingDestination = null);
        _showSnackBar("Impossible de generer l'image");
        return;
      }

      // 2. Execute the destination-specific share action
      final result = await _service.shareToDestination(
        imageBytes: bytes,
        destination: destination,
        year: widget.data.year,
      );

      if (!mounted) return;

      // 3. Show feedback based on result
      switch (result) {
        case ShareResult.savedToGallery:
          Navigator.pop(context);
          _showSnackBar('Image sauvegardee \u2713');
        case ShareResult.openedApp:
          Navigator.pop(context);
          _showSnackBar('Image sauvegardee — ouvre ${destination.label}');
        case ShareResult.sharedGeneric:
          setState(() => _loadingDestination = null);
          Navigator.pop(context);
        case ShareResult.error:
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
        backgroundColor: YearlyColors.gold.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: YearlyColors.deepBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            'Partage ton Wrapped \u2728',
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

          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  destination.icon,
                  style: const TextStyle(fontSize: 22),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(YearlyColors.gold),
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

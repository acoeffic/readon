import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  Future<void> shareToDestination({
    required Uint8List imageBytes,
    required ShareDestination destination,
    required int year,
    Rect? sharePositionOrigin,
  }) async {
    final text = 'Mon annee de lecture $year \uD83D\uDCDA\u2728 #LexstaWrapped';

    // Destinations that go directly to the native share sheet
    if (destination == ShareDestination.whatsapp ||
        destination == ShareDestination.message ||
        destination == ShareDestination.more) {
      final file = await _saveTempFile(imageBytes, destination.format, year);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    // Try deep-linking into the target app
    final scheme = destination.urlScheme;
    if (scheme != null) {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // App not installed — open web version in browser
    final webUrl = destination.webFallbackUrl;
    if (webUrl != null) {
      await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    // Last resort — native share sheet
    final file = await _saveTempFile(imageBytes, destination.format, year);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    );
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
    Future.delayed(const Duration(seconds: 60), () => file.delete().catchError((_) => file));
    return file;
  }
}

// ==========================================================================
// Bottom sheet — called from slide_final.dart
// ==========================================================================

/// Shows the share bottom sheet with card preview + icon grid.
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
  Uint8List? _capturedImage;
  bool _isCapturing = true;
  ShareDestination? _loadingDestination;

  @override
  void initState() {
    super.initState();
    _capturePreview();
  }

  Future<void> _capturePreview() async {
    final bytes = await _service.captureCard(
      data: widget.data,
      format: ShareFormat.story,
    );
    if (!mounted) return;
    setState(() {
      _capturedImage = bytes;
      _isCapturing = false;
    });
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _onDestinationTap(ShareDestination destination) async {
    if (_loadingDestination != null || _capturedImage == null) return;
    setState(() => _loadingDestination = destination);

    try {
      await _service.shareToDestination(
        imageBytes: _capturedImage!,
        destination: destination,
        year: widget.data.year,
        sharePositionOrigin: _shareOrigin(),
      );

      if (!mounted) return;
      Navigator.pop(context);
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
          const SizedBox(height: 16),

          // Header: Fermer + Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Fermer',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Partager ton Wrapped',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Opacity(
                  opacity: 0,
                  child: Text(
                    'Fermer',
                    style: GoogleFonts.jetBrainsMono(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card preview
          SizedBox(
            height: 320,
            child: _isCapturing
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(YearlyColors.gold),
                    ),
                  )
                : _capturedImage != null
                    ? Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _capturedImage!,
                              height: 320,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          'Erreur',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 24),

          // "Partager sur"
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Partager sur',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Destination grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: ShareDestination.values.map((dest) {
                return _DestinationIcon(
                  destination: dest,
                  isLoading: _loadingDestination == dest,
                  enabled: _loadingDestination == null && !_isCapturing,
                  onTap: () => _onDestinationTap(dest),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: bottomPadding + 24),
        ],
      ),
    );
  }
}

// ==========================================================================
// Destination icon widget
// ==========================================================================

class _DestinationIcon extends StatelessWidget {
  final ShareDestination destination;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _DestinationIcon({
    required this.destination,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: destination.brandColor,
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Center(
                      child: Icon(
                        destination.iconData,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              destination.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

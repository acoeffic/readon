import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book.dart';
import '../../models/reading_sheet.dart';
import '../../features/wrapped/share/share_format.dart';
import '../../theme/app_theme.dart';
import 'reading_sheet_share_card.dart';

// ==========================================================================
// Service
// ==========================================================================

class ReadingSheetShareService {
  final _screenshotController = ScreenshotController();

  /// Capture the [ReadingSheetShareCard] as a high-res PNG.
  Future<Uint8List?> captureCard({
    required Book book,
    required ReadingSheet readingSheet,
  }) async {
    final card = ReadingSheetShareCard(
      book: book,
      readingSheet: readingSheet,
    );
    return _screenshotController.captureFromWidget(
      card,
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 200),
    );
  }

  /// Build the share text for reading sheet.
  String buildShareText(Book book, ReadingSheet readingSheet) {
    final author = book.author;
    final titlePart =
        author != null ? '${book.title} de $author' : book.title;

    final themeNames = readingSheet.themes.take(3).map((t) => t.title).join(', ');

    return '\u{1F4D6} Ma fiche de lecture de $titlePart\n'
        '${readingSheet.annotationCount} annotations analysées par l\'IA\n'
        '${themeNames.isNotEmpty ? 'Thèmes : $themeNames\n' : ''}'
        '\nlexday.app';
  }

  /// Build the full reading sheet as plain text for clipboard copy.
  String buildFullText(Book book, ReadingSheet sheet) {
    final buffer = StringBuffer();

    final author = book.author;
    final titlePart = author != null ? '${book.title} de $author' : book.title;
    buffer.writeln('FICHE DE LECTURE — $titlePart');
    buffer.writeln();

    if (sheet.themes.isNotEmpty) {
      buffer.writeln('THÈMES PRINCIPAUX');
      for (final theme in sheet.themes) {
        buffer.writeln('• ${theme.title} : ${theme.description}');
      }
      buffer.writeln();
    }

    if (sheet.quotes.isNotEmpty) {
      buffer.writeln('CITATIONS NOTABLES');
      for (final quote in sheet.quotes) {
        final page = quote.page != null ? ' (p. ${quote.page})' : '';
        buffer.writeln('« ${quote.text} »$page — ${quote.comment}');
      }
      buffer.writeln();
    }

    if (sheet.progression.isNotEmpty) {
      buffer.writeln('PROGRESSION DE PENSÉE');
      buffer.writeln(sheet.progression);
      buffer.writeln();
    }

    if (sheet.synthesis.isNotEmpty) {
      buffer.writeln('SYNTHÈSE PERSONNELLE');
      buffer.writeln(sheet.synthesis);
      buffer.writeln();
    }

    buffer.writeln('Généré par LexDay — lexday.app');
    return buffer.toString();
  }

  /// Execute the share action for a specific [destination].
  Future<void> shareToDestination({
    required Uint8List imageBytes,
    required ShareDestination destination,
    required Book book,
    required ReadingSheet readingSheet,
    Rect? sharePositionOrigin,
  }) async {
    final text = buildShareText(book, readingSheet);

    if (destination == ShareDestination.whatsapp ||
        destination == ShareDestination.message ||
        destination == ShareDestination.more) {
      final file = await _saveTempFile(imageBytes, book.id);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    final scheme = destination.urlScheme;
    if (scheme != null) {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final webUrl = destination.webFallbackUrl;
    if (webUrl != null) {
      await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    final file = await _saveTempFile(imageBytes, book.id);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<File> _saveTempFile(Uint8List bytes, int bookId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/lexday_reading_sheet_$bookId.png');
    await file.writeAsBytes(bytes);
    Future.delayed(const Duration(seconds: 60), () => file.delete().catchError((_) => file));
    return file;
  }
}

// ==========================================================================
// Bottom sheet
// ==========================================================================

/// Shows the reading sheet share bottom sheet with card preview + icon grid.
Future<void> showReadingSheetShareSheet({
  required BuildContext context,
  required Book book,
  required ReadingSheet readingSheet,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReadingSheetShareSheet(book: book, readingSheet: readingSheet),
  );
}

class _ReadingSheetShareSheet extends StatefulWidget {
  final Book book;
  final ReadingSheet readingSheet;

  const _ReadingSheetShareSheet({
    required this.book,
    required this.readingSheet,
  });

  @override
  State<_ReadingSheetShareSheet> createState() =>
      _ReadingSheetShareSheetState();
}

class _ReadingSheetShareSheetState extends State<_ReadingSheetShareSheet> {
  final _service = ReadingSheetShareService();
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
      book: widget.book,
      readingSheet: widget.readingSheet,
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
        book: widget.book,
        readingSheet: widget.readingSheet,
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

  Future<void> _copyText() async {
    final text = _service.buildFullText(widget.book, widget.readingSheet);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    Navigator.pop(context);
    _showSnackBar('Fiche copiée dans le presse-papier');
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1408),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
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

          // ── Header ──
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
                  'Partager',
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

          // ── Card preview ──
          SizedBox(
            height: 320,
            child: _isCapturing
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFD4A855)),
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

          // ── Copy text button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _copyText,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Copier le texte',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── "Partager sur" ──
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

          // ── Destination grid ──
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

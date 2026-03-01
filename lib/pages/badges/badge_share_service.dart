import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/badges_service.dart';
import '../../features/wrapped/share/share_format.dart';
import '../../theme/app_theme.dart';
import 'badge_share_card.dart';

// ==========================================================================
// Service
// ==========================================================================

class BadgeShareService {
  final _screenshotController = ScreenshotController();
  final _supabase = Supabase.instance.client;

  /// Generate badge card server-side via Edge Function.
  /// Returns the public URL of the generated PNG.
  Future<String> generateServerCard({required String badgeId}) async {
    final response = await _supabase.functions.invoke(
      'generate-badge-card',
      body: {'badge_id': badgeId},
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) {
        throw Exception(data['message'] ?? data['error'] ?? 'Erreur serveur');
      }
      final url = data['url'] as String?;
      if (url != null) return url;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error')) {
          throw Exception(decoded['message'] ?? decoded['error']);
        }
        final url = decoded['url'] as String?;
        if (url != null) return url;
      }
    }

    throw Exception('Réponse inattendue du serveur');
  }

  /// Download a PNG from [url] and return its bytes.
  Future<Uint8List> downloadImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Erreur téléchargement image');
    }
    return response.bodyBytes;
  }

  /// Capture badge card client-side (fallback).
  Future<Uint8List?> captureCard({
    required UserBadge badge,
    required ShareFormat format,
  }) async {
    final card = BadgeShareCard(badge: badge, format: format);
    return _screenshotController.captureFromWidget(
      card,
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 200),
    );
  }

  Future<void> shareToDestination({
    required Uint8List imageBytes,
    required ShareDestination destination,
    required UserBadge badge,
    Rect? sharePositionOrigin,
  }) async {
    final text =
        'Je viens de débloquer le badge "${badge.name}" \uD83C\uDFC6 #LexDay';

    if (destination == ShareDestination.whatsapp ||
        destination == ShareDestination.message ||
        destination == ShareDestination.more) {
      final file = await _saveTempFile(imageBytes, badge.id);
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

    final file = await _saveTempFile(imageBytes, badge.id);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<File> _saveTempFile(Uint8List bytes, String badgeId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/readon_badge_$badgeId.png');
    await file.writeAsBytes(bytes);
    Future.delayed(const Duration(seconds: 60), () => file.delete().catchError((_) => file));
    return file;
  }
}

// ==========================================================================
// Bottom sheet
// ==========================================================================

Future<void> showBadgeShareSheet({
  required BuildContext context,
  required UserBadge badge,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BadgeShareSheet(badge: badge),
  );
}

class _BadgeShareSheet extends StatefulWidget {
  final UserBadge badge;
  const _BadgeShareSheet({required this.badge});

  @override
  State<_BadgeShareSheet> createState() => _BadgeShareSheetState();
}

class _BadgeShareSheetState extends State<_BadgeShareSheet> {
  final _service = BadgeShareService();
  Uint8List? _capturedImage;
  bool _isCapturing = true;
  ShareDestination? _loadingDestination;

  @override
  void initState() {
    super.initState();
    _capturePreview();
  }

  Future<void> _capturePreview() async {
    try {
      // Try server-side generation first
      final url = await _service.generateServerCard(
        badgeId: widget.badge.id,
      );
      final bytes = await _service.downloadImage(url);
      if (!mounted) return;
      setState(() {
        _capturedImage = bytes;
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint('Server card generation failed, falling back to client: $e');
      // Fallback to client-side capture
      final bytes = await _service.captureCard(
        badge: widget.badge,
        format: ShareFormat.story,
      );
      if (!mounted) return;
      setState(() {
        _capturedImage = bytes;
        _isCapturing = false;
      });
    }
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
        badge: widget.badge,
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
        color: Color(0xFF0A1F1A),
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

          // Header
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

          // Card preview
          SizedBox(
            height: 320,
            child: _isCapturing
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
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

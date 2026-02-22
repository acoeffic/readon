import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../monthly_wrapped_data.dart';
import '../../../share/monthly_share_service.dart';
import '../../../share/share_format.dart';
import '../../../../../services/readon_sync_service.dart';
import '../fade_up_animation.dart';

/// Slide 4 – Conclusion message + mini-stats + share button + direct app links.
class ShareSlide extends StatefulWidget {
  final MonthlyWrappedData data;
  final MonthTheme theme;

  const ShareSlide({super.key, required this.data, required this.theme});

  @override
  State<ShareSlide> createState() => _ShareSlideState();
}

class _ShareSlideState extends State<ShareSlide> {
  final _service = MonthlyShareService();
  String? _loadingAction; // tracks which action is in progress
  File? _videoFile;
  bool _hasVideo = false;

  MonthlyWrappedData get data => widget.data;
  MonthTheme get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadVideoAsset();
  }

  /// Try to fetch the pre-rendered video from readon-sync (background).
  Future<void> _loadVideoAsset() async {
    try {
      final assets = await ReadonSyncService.getMonthlyWrappedShareAssets(
        data.month,
        data.year,
      );
      if (!mounted) return;

      if (assets.hasVideo) {
        final videoResponse = await http.get(Uri.parse(assets.videoUrl!));
        if (videoResponse.statusCode == 200 && mounted) {
          final dir = await getTemporaryDirectory();
          final file = File(
            '${dir.path}/lexday_wrapped_${data.year}_${data.month}.mp4',
          );
          await file.writeAsBytes(videoResponse.bodyBytes);
          if (mounted) {
            setState(() {
              _videoFile = file;
              _hasVideo = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('ShareSlide video fetch error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Share actions
  // ---------------------------------------------------------------------------

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Big button — opens native share sheet with video (or image fallback).
  Future<void> _shareGeneric() async {
    if (_loadingAction != null) return;
    setState(() => _loadingAction = 'generic');

    try {
      final bytes = await _service.captureCard(
        data: data,
        format: ShareFormat.story,
      );
      if (!mounted || bytes == null || bytes.isEmpty) {
        _reset();
        _showSnackBar("Impossible de generer l'image");
        return;
      }

      await _service.shareGeneric(
        imageBytes: bytes,
        year: data.year,
        month: data.month,
        videoFile: _hasVideo ? _videoFile : null,
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (_) {}
    _reset();
  }

  /// Opens a specific social app (save temp + URL scheme, no gallery dependency).
  Future<void> _shareToApp(String appName, String urlScheme, ShareFormat format, {String? webFallbackUrl}) async {
    if (_loadingAction != null) return;
    setState(() => _loadingAction = appName);

    try {
      final bytes = await _service.captureCard(
        data: data,
        format: format,
      );
      if (!mounted || bytes == null || bytes.isEmpty) {
        _reset();
        _showSnackBar("Impossible de generer l'image");
        return;
      }

      final opened = await _service.shareToApp(
        imageBytes: bytes,
        urlScheme: urlScheme,
        year: data.year,
        month: data.month,
        videoFile: _hasVideo ? _videoFile : null,
        webFallbackUrl: webFallbackUrl,
        sharePositionOrigin: _shareOrigin(),
      );
      if (!mounted) return;

      if (opened) {
        _showSnackBar('Ouverture de $appName...');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur : $e');
    }
    _reset();
  }

  /// Copies the image/video via the native share sheet.
  Future<void> _shareCopy() async {
    if (_loadingAction != null) return;
    setState(() => _loadingAction = 'copier');

    try {
      final bytes = await _service.captureCard(
        data: data,
        format: ShareFormat.story,
      );
      if (!mounted || bytes == null || bytes.isEmpty) {
        _reset();
        _showSnackBar("Impossible de generer l'image");
        return;
      }

      await _service.shareGeneric(
        imageBytes: bytes,
        year: data.year,
        month: data.month,
        videoFile: _hasVideo ? _videoFile : null,
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e) {
      if (mounted) _showSnackBar('Erreur : $e');
    }
    _reset();
  }

  void _reset() {
    if (mounted) setState(() => _loadingAction = null);
  }

  void _showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.accent.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isGood = data.vsLastMonthPercent > 0;
    final nextMonth =
        getMonthName(data.month == 12 ? 1 : data.month + 1).toLowerCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(theme.emoji, style: const TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 12),
        FadeUp(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
              children: [
                TextSpan(text: '${data.monthName} a ete\n'),
                TextSpan(
                  text: isGood ? 'un super mois' : 'un mois tranquille',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeUp(
          child: Text(
            'On se retrouve en $nextMonth ?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Mini stats
        FadeUp(
          delay: const Duration(milliseconds: 300),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniStat(
                value: '${data.totalMinutes ~/ 60}h',
                label: 'LU',
                accent: theme.accent,
              ),
              const SizedBox(width: 10),
              _MiniStat(
                value: '${data.booksFinished}',
                label: 'FINIS',
                accent: theme.accent,
              ),
              const SizedBox(width: 10),
              _MiniStat(
                value: '${data.longestFlow}j',
                label: 'FLOW',
                accent: theme.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Big share button — golden gradient
        FadeUp(
          delay: const Duration(milliseconds: 500),
          child: _ShareButton(
            year: data.year,
            accent: theme.accent,
            isLoading: _loadingAction == 'generic',
            onTap: _shareGeneric,
          ),
        ),
        const SizedBox(height: 20),

        // Direct app links row
        FadeUp(
          delay: const Duration(milliseconds: 600),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AppLink(
                label: 'Instagram',
                isLoading: _loadingAction == 'Instagram',
                onTap: () => _shareToApp(
                  'Instagram',
                  'instagram://app',
                  ShareFormat.story,
                  webFallbackUrl: 'https://www.instagram.com',
                ),
              ),
              const SizedBox(width: 24),
              _AppLink(
                label: 'Twitter',
                isLoading: _loadingAction == 'Twitter',
                onTap: () => _shareToApp(
                  'Twitter',
                  'twitter://post',
                  ShareFormat.square,
                  webFallbackUrl: 'https://x.com',
                ),
              ),
              const SizedBox(width: 24),
              _AppLink(
                label: 'LinkedIn',
                isLoading: _loadingAction == 'LinkedIn',
                onTap: () => _shareToApp(
                  'LinkedIn',
                  'linkedin://app',
                  ShareFormat.square,
                  webFallbackUrl: 'https://www.linkedin.com',
                ),
              ),
              const SizedBox(width: 24),
              _AppLink(
                label: 'Copier',
                isLoading: _loadingAction == 'copier',
                onTap: _shareCopy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        FadeUp(
          delay: const Duration(milliseconds: 700),
          child: Text(
            'READON',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.15),
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Big golden share button
// ---------------------------------------------------------------------------

class _ShareButton extends StatelessWidget {
  final int year;
  final Color accent;
  final bool isLoading;
  final VoidCallback onTap;

  const _ShareButton({
    required this.year,
    required this.accent,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              accent.withValues(alpha: 0.9),
              accent.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : Text(
                  'Partager mon Wrapped $year',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Underlined text link for a specific app
// ---------------------------------------------------------------------------

class _AppLink extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _AppLink({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.5),
                ),
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.5),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini stat pill
// ---------------------------------------------------------------------------

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.3),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

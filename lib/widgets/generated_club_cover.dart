// lib/widgets/generated_club_cover.dart
// Couverture de club générée procéduralement quand aucune image n'a été
// uploadée. Le dégradé et les initiales sont déterministes à partir du nom :
// même nom → toujours mêmes couleurs. Inspiré du pattern Discord / Spotify.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GeneratedClubCover extends StatelessWidget {
  final String name;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double initialsFontSize;
  final bool showDecoration;

  const GeneratedClubCover({
    super.key,
    required this.name,
    this.width,
    this.height,
    this.borderRadius,
    this.initialsFontSize = 36,
    this.showDecoration = true,
  });

  /// Palette de dégradés curatés — chaud/élégant, sans clash avec la marque.
  static const List<List<Color>> _palettes = [
    [Color(0xFF6B988D), Color(0xFF466B62)], // sage green
    [Color(0xFF8B7355), Color(0xFF5C4A36)], // warm brown
    [Color(0xFF7A6F8E), Color(0xFF514764)], // muted purple
    [Color(0xFF8A6B5E), Color(0xFF5E4A40)], // terracotta
    [Color(0xFF5E7A8A), Color(0xFF3F5664)], // steel blue
    [Color(0xFF8B8B6B), Color(0xFF65654C)], // olive
    [Color(0xFF6B7A8B), Color(0xFF475569)], // slate
    [Color(0xFF9B7A6B), Color(0xFF6B5145)], // dusty rose
    [Color(0xFF2A3A5A), Color(0xFF1A2B45)], // navy
    [Color(0xFFC6A85A), Color(0xFFA68B3F)], // gold
    [Color(0xFF4F6D6E), Color(0xFF334D4E)], // teal deep
    [Color(0xFF8E5C5C), Color(0xFF623F3F)], // crimson dust
  ];

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return w.substring(0, w.length.clamp(0, 2)).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  List<Color> get _palette {
    final hash = name.hashCode.abs();
    return _palettes[hash % _palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
      ),
      clipBehavior: borderRadius != null ? Clip.antiAlias : Clip.none,
      child: Stack(
        children: [
          if (showDecoration)
            Positioned(
              right: -16,
              bottom: -22,
              child: Text(
                '📖',
                style: TextStyle(
                  fontSize: initialsFontSize * 2.6,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          Center(
            child: Text(
              _initials,
              style: GoogleFonts.cormorantGaramond(
                fontSize: initialsFontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

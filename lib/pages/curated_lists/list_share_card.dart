import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couverture à afficher sur la carte : bytes pré-téléchargés, ou titre
/// en fallback quand le livre n'a pas de couverture.
class ListShareCover {
  final Uint8List? bytes;
  final String title;

  const ListShareCover({this.bytes, required this.title});
}

const _textDark = Color(0xFF2D2D2D);
const _textMuted = Color(0xFF9B9585);

/// Carte de partage d'une liste perso, rendue hors écran et capturée en
/// image. Format story (360×640 logique, capturée à 3x → 1080×1920).
class ListShareCard extends StatelessWidget {
  final String title;
  final String booksLabel; // ex. « 8 livres »
  final IconData icon;
  final List<Color> gradientColors;
  final List<ListShareCover> covers; // 6 max

  const ListShareCard({
    super.key,
    required this.title,
    required this.booksLabel,
    required this.icon,
    required this.gradientColors,
    required this.covers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 30,
            right: -30,
            child: Icon(
              icon,
              size: 200,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 56),
              Icon(icon, size: 30, color: Colors.white),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CoverGrid(covers: covers),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booksLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'LexDay',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'lexday.fr',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 44),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverGrid extends StatelessWidget {
  final List<ListShareCover> covers;

  const _CoverGrid({required this.covers});

  @override
  Widget build(BuildContext context) {
    if (covers.isEmpty) {
      return const SizedBox(height: 8);
    }
    final rows = <List<ListShareCover>>[];
    for (var i = 0; i < covers.length; i += 3) {
      rows.add(covers.sublist(i, (i + 3).clamp(0, covers.length)));
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final cover in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _CoverTile(cover: cover),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CoverTile extends StatelessWidget {
  final ListShareCover cover;

  const _CoverTile({required this.cover});

  @override
  Widget build(BuildContext context) {
    const width = 76.0;
    const height = 112.0;
    final bytes = cover.bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: bytes != null
          ? Image.memory(
              bytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
            )
          : Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(6),
              color: const Color(0xFFF5F0E8),
              alignment: Alignment.center,
              child: Text(
                cover.title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                  height: 1.3,
                ),
              ),
            ),
    );
  }
}

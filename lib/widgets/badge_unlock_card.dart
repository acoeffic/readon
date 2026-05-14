// lib/widgets/badge_unlock_card.dart
//
// Editorial unlock card — fond sage, médaillon parchemin avec l'artwork du
// badge, typo serif Cormorant + accent or. Utilisable :
//   1. Affichée plein-écran dans BadgeUnlockedDialog (après le confetti d'intro)
//   2. Rendue off-screen et capturée pour le partage (à venir)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/badges_service.dart';
import 'remote_badge_image.dart';

class BadgeUnlockCard extends StatelessWidget {
  final UserBadge badge;
  final DateTime date;

  const BadgeUnlockCard({
    super.key,
    required this.badge,
    required this.date,
  });

  // ── Palette éditoriale ──
  static const _bgSage = Color(0xFF3F5A4D);
  static const _bgSageDark = Color(0xFF34493F);
  static const _gold = Color(0xFFD4B570);
  static const _goldSoft = Color(0xFFC6A85A);
  static const _parchment = Color(0xFFF5EFD9);
  static const _parchmentDark = Color(0xFFE8DEC0);

  static const _frenchMonths = [
    '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  String get _formattedDate => '${date.day} ${_frenchMonths[date.month]} ${date.year}';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgSage, _bgSageDark],
        ),
      ),
      child: Stack(
        children: [
          // ── Cadre or fin ──
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.45),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),

          // ── Feuilles décoratives bas-gauche / bas-droite ──
          Positioned(
            left: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.12,
              child: Text(
                '\u{1F33F}',
                style: TextStyle(fontSize: 110, color: _gold),
              ),
            ),
          ),
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.12,
              child: Text(
                '\u{1F33F}',
                style: TextStyle(fontSize: 110, color: _gold),
              ),
            ),
          ),

          // ── Contenu ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                children: [
                  _buildHeader(),
                  const Spacer(flex: 2),
                  _buildBadgeLabel(),
                  const SizedBox(height: 32),
                  _buildMedallion(),
                  const SizedBox(height: 36),
                  _buildTitle(),
                  const SizedBox(height: 14),
                  _buildSubtitle(),
                  const Spacer(flex: 3),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: _gold.withValues(alpha: 0.7), width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'L',
                style: GoogleFonts.cormorantGaramond(
                  color: _gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'LEXDAY',
              style: GoogleFonts.cormorantGaramond(
                color: _gold,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        Text(
          _formattedDate,
          style: GoogleFonts.cormorantGaramond(
            color: _gold.withValues(alpha: 0.85),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeLabel() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _decorativeLine(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.emoji_events_outlined, color: _gold, size: 22),
            ),
            _decorativeLine(),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'BADGE DÉBLOQUÉ',
          style: GoogleFonts.cormorantGaramond(
            color: _gold,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _smallDot(),
            const SizedBox(width: 6),
            _smallDot(),
            const SizedBox(width: 6),
            _smallDot(),
          ],
        ),
      ],
    );
  }

  Widget _decorativeLine() {
    return Container(
      width: 60,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0),
            _gold.withValues(alpha: 0.6),
            _gold.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  Widget _smallDot() {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMedallion() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth * 0.75).clamp(160.0, 260.0);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [_parchment, _parchmentDark],
              stops: [0.6, 1.0],
            ),
            border: Border.all(color: _gold, width: 4),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: RemoteBadgeImage.fromBadge(badge, size: size - 60),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Text(
      badge.name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.cormorantGaramond(
        color: _parchment,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSubtitle() {
    if (badge.description.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        badge.description,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cormorantGaramond(
          color: _goldSoft,
          fontSize: 17,
          fontStyle: FontStyle.italic,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _decorativeLine(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('❖',
                  style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 10)),
            ),
            _decorativeLine(),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'SUIS MA LECTURE SUR LEXDAY.APP',
          style: GoogleFonts.cormorantGaramond(
            color: _gold.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

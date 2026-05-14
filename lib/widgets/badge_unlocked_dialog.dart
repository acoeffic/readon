// lib/widgets/badge_unlocked_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/badges_service.dart';
import '../theme/app_theme.dart';
import 'badge_unlock_card.dart';
import '../pages/badges/badge_share_service.dart';

class BadgeUnlockedDialog extends StatefulWidget {
  final UserBadge badge;

  const BadgeUnlockedDialog({
    super.key,
    required this.badge,
  });

  @override
  State<BadgeUnlockedDialog> createState() => _BadgeUnlockedDialogState();
}

class _BadgeUnlockedDialogState extends State<BadgeUnlockedDialog>
    with TickerProviderStateMixin {
  // Phase 1 : confetti d'intro (1s)
  late AnimationController _confettiController;
  // Phase 2 : card éditorial qui fade-in
  late AnimationController _cardController;
  late Animation<double> _cardFade;
  late Animation<double> _cardScale;
  bool _showCard = false;

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _cardFade = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
    _cardScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    HapticFeedback.mediumImpact();
    _confettiController.forward();

    // Transition vers le card à la fin du confetti
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showCard = true);
      _cardController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Color _confettiColor(int index) {
    if (widget.badge.isSecret) return Colors.purple.shade300;
    return const [
      Color(0xFFD4B570),
      AppColors.primary,
      AppColors.sageGreen,
      Color(0xFFF5EFD9),
    ][index % 4];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // ── Phase 2 : le card édito en fond, fade-in ──
          if (_showCard)
            Positioned.fill(
              child: FadeTransition(
                opacity: _cardFade,
                child: ScaleTransition(
                  scale: _cardScale,
                  child: BadgeUnlockCard(
                    badge: widget.badge,
                    date: DateTime.now(),
                  ),
                ),
              ),
            ),

          // ── Phase 1 : confetti d'intro pendant ~1s ──
          if (!_cardController.isCompleted)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return Stack(
                    children: List.generate(24, (index) {
                      final rng = math.Random(index);
                      final startX = 0.5 + (rng.nextDouble() - 0.5) * 0.4;
                      final endX = startX +
                          (math.Random(index + 100).nextDouble() - 0.5) * 0.7;
                      final endY = 0.85 +
                          math.Random(index + 200).nextDouble() * 0.15;
                      final rotation =
                          math.Random(index + 300).nextDouble() * 4 * math.pi;
                      final progress = _confettiController.value;
                      return Positioned(
                        left: size.width *
                            (startX + (endX - startX) * progress),
                        top: size.height * (-0.1 + endY * progress),
                        child: Transform.rotate(
                          angle: rotation * progress,
                          child: Opacity(
                            opacity: 1.0 - progress,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _confettiColor(index),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

          // ── Close button (toujours visible) ──
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: const Color(0xFFD4B570).withValues(alpha: 0.85),
                    size: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // ── Share button — apparaît avec le card ──
          if (_showCard)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        showBadgeShareSheet(
                          context: context,
                          badge: widget.badge,
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text(
                        'Partager',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFD4B570).withValues(alpha: 0.95),
                        foregroundColor: const Color(0xFF34493F),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

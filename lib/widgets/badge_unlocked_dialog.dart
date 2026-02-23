// lib/widgets/badge_unlocked_dialog.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/badges_service.dart';
import '../theme/app_theme.dart';
import '../features/badges/widgets/first_book_badge_painter.dart';
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
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _confettiController;
  late AnimationController? _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Animation d'échelle pour le badge
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Animation de rotation
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // Animation de confetti
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Shimmer pour badges secrets
    if (widget.badge.isSecret) {
      _shimmerController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat();
    } else {
      _shimmerController = null;
    }

    // Démarrer les animations
    _scaleController.forward();
    _rotationController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _confettiController.dispose();
    _shimmerController?.dispose();
    super.dispose();
  }

  Color _getBadgeColor() {
    try {
      final colorStr = widget.badge.color.replaceAll('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (e) {
      return Colors.amber;
    }
  }

  String get _dialogTitle {
    if (widget.badge.isSecret) return 'Badge Secret Révélé!';
    if (widget.badge.isPremium) return 'Badge Premium!';
    return 'Nouveau Badge!';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();
    final isSecret = widget.badge.isSecret;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti en arrière-plan
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                final startX = 0.5 + (math.Random(index).nextDouble() - 0.5) * 0.4;
                final endX = startX + (math.Random(index + 100).nextDouble() - 0.5) * 0.6;
                final endY = 0.8 + math.Random(index + 200).nextDouble() * 0.2;
                final rotation = math.Random(index + 300).nextDouble() * 4 * math.pi;

                return Positioned(
                  left: MediaQuery.of(context).size.width *
                      (startX + (endX - startX) * _confettiController.value),
                  top: MediaQuery.of(context).size.height *
                      (-0.1 + endY * _confettiController.value),
                  child: Transform.rotate(
                    angle: rotation * _confettiController.value,
                    child: Opacity(
                      opacity: 1.0 - _confettiController.value,
                      child: isSecret
                          ? Text(
                              ['🕵️', '✨', '🔮', '⭐', '💫'][index % 5],
                              style: const TextStyle(fontSize: 16),
                            )
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: [
                                  Colors.amber,
                                  Colors.orange,
                                  Colors.pink,
                                  AppColors.primary,
                                  Colors.blue,
                                ][index % 5],
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenu principal
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isSecret
                        ? Colors.purple.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium crown
                  if (widget.badge.isPremium) ...[
                    const Text('👑', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                  ],

                  // Titre
                  Text(
                    _dialogTitle,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isSecret ? Colors.purple : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Badge animé
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value,
                          child: isFirstBookBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const FirstBookBadge(size: 120)
                              : isApprenticeReaderBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const ApprenticeReaderBadge(size: 120)
                              : isConfirmedReaderBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const ConfirmedReaderBadge(size: 120, animate: true, showUnlockBurst: true)
                              : isBibliophileBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const BibliophileBadge(size: 120)
                              : isOneHourMagicBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OneHourMagicBadge(size: 120)
                              : isSundayReaderBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const SundayReaderBadge(size: 120)
                              : isPassionateBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const PassionateBadge(size: 120)
                              : isCenturionBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const CenturionBadge(size: 120)
                              : isMarathonBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const MarathonBadge(size: 120)
                              : isHalfMillenniumBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const HalfMillenniumBadge(size: 120)
                              : isMillenniumBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const MillenniumBadge(size: 120)
                              : isClubFounderBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const ClubFounderBadge(size: 120)
                              : isClubLeaderBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const ClubLeaderBadge(size: 120)
                              : isResidentBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const ResidentBadge(size: 120)
                              : isHabitueBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const HabitueBadge(size: 120)
                              : isPilierBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const PilierBadge(size: 120)
                              : isMonumentBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const MonumentBadge(size: 120)
                              : isAnnualOnePerMonthBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const AnnualOnePerMonthBadge(size: 120)
                              : isAnnualTwoPerMonthBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const AnnualTwoPerMonthBadge(size: 120)
                              : isAnnualOnePerWeekBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const AnnualOnePerWeekBadge(size: 120)
                              : isAnnualCentenaireBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const AnnualCentenaireBadge(size: 120)
                              : isOccasionBastilleDayBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionBastilleDayBadge(size: 120)
                              : isOccasionChristmasBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionChristmasBadge(size: 120)
                              : isOccasionFeteMusiqueBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionFeteMusiqueBadge(size: 120)
                              : isOccasionHalloweenBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionHalloweenBadge(size: 120)
                              : isOccasionSummerReadBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionSummerReadBadge(size: 120)
                              : isOccasionValentineBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionValentineBadge(size: 120)
                              : isOccasionNyeBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionNyeBadge(size: 120)
                              : isOccasionLabourDayBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionLabourDayBadge(size: 120)
                              : isOccasionWorldBookDayBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionWorldBookDayBadge(size: 120)
                              : isOccasionNewYearBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionNewYearBadge(size: 120)
                              : isOccasionEasterBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionEasterBadge(size: 120)
                              : isOccasionAprilFoolsBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const OccasionAprilFoolsBadge(size: 120)
                              : isGenreSfInitieBadge(id: widget.badge.id, category: widget.badge.category, requirement: widget.badge.requirement)
                              ? const GenreSfInitieBadge(size: 120)
                              : Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getBadgeColor().withValues(alpha: 0.2),
                                    border: Border.all(
                                      color: _getBadgeColor(),
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getBadgeColor().withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                      if (isSecret)
                                        BoxShadow(
                                          color: Colors.purple.withValues(alpha: 0.2),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.badge.icon,
                                      style: const TextStyle(fontSize: 60),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nom du badge
                  Text(
                    widget.badge.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  if (widget.badge.description.isNotEmpty)
                    Text(
                      widget.badge.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: 24),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Partager
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showBadgeShareSheet(
                            context: context,
                            badge: widget.badge,
                          );
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'Partager',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getBadgeColor(),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Fermer
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _getBadgeColor(),
                          side: BorderSide(color: _getBadgeColor()),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Super!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

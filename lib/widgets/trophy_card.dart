// lib/widgets/trophy_card.dart
// Widget pour afficher un trophée dans la page de résumé de session

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/trophy.dart';
import '../theme/app_theme.dart';

class TrophyCard extends StatelessWidget {
  final Trophy trophy;

  const TrophyCard({super.key, required this.trophy});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              trophy.icon,
              style: const TextStyle(fontSize: 56),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          trophy.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          trophy.description,
          style: TextStyle(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Dialog animé pour les trophées débloquables nouvellement gagnés
class TrophyUnlockedDialog extends StatefulWidget {
  final Trophy trophy;

  const TrophyUnlockedDialog({super.key, required this.trophy});

  @override
  State<TrophyUnlockedDialog> createState() => _TrophyUnlockedDialogState();
}

class _TrophyUnlockedDialogState extends State<TrophyUnlockedDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                final startX = 0.5 + (index % 5 - 2) * 0.15;
                final endX = startX + (index % 3 - 1) * 0.3;
                final endY = 0.8 + (index % 4) * 0.05;
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
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: [
                            AppColors.primary,
                            Colors.amber,
                            Colors.orange,
                            Colors.teal,
                            Colors.green,
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

          // Contenu
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nouveau Trophée !',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.trophy.icon,
                          style: const TextStyle(fontSize: 60),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    widget.trophy.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.trophy.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Super !',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

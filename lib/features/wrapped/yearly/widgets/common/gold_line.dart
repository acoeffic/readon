import 'package:flutter/material.dart';
import '../yearly_animations.dart';

/// Decorative gold line: transparent → gold → transparent.
class GoldLine extends StatelessWidget {
  final double width;
  final Duration delay;

  const GoldLine({super.key, this.width = 60, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: delay,
      child: Container(
        width: width,
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              YearlyColors.gold.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

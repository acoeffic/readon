import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class OnboardingDots extends StatelessWidget {
  final int total;
  final int current;

  const OnboardingDots({
    super.key,
    required this.total,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == current ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == current
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

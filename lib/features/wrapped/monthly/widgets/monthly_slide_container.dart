import 'package:flutter/material.dart';
import '../monthly_wrapped_data.dart';

/// Provides the gradient card, progress bar, tap-navigation and the outer
/// chrome ("Monthly Wrapped" label + navigation hint) seen in the mockup.
class MonthlySlideContainer extends StatelessWidget {
  final int currentSlide;
  final int slideCount;
  final MonthTheme theme;
  final ValueChanged<int> onNavigate;
  final VoidCallback? onClose;
  final bool isMuted;
  final VoidCallback? onToggleMute;
  final Widget child;

  const MonthlySlideContainer({
    super.key,
    required this.currentSlide,
    required this.slideCount,
    required this.theme,
    required this.onNavigate,
    required this.child,
    this.onClose,
    this.isMuted = false,
    this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Header row: label + close button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Mute toggle (left side)
              if (onToggleMute != null)
                GestureDetector(
                  onTap: onToggleMute,
                  child: Icon(
                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                )
              else
                const SizedBox(width: 20),
              const Spacer(),
              Text(
                'MONTHLY WRAPPED',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              if (onClose != null)
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Progress bars
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: List.generate(slideCount, (i) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => onNavigate(i),
                  child: Padding(
                    padding: EdgeInsets.only(right: i < slideCount - 1 ? 3 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i <= currentSlide
                            ? theme.accent
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),

        // Main card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) {
                    final half = constraints.maxWidth / 2;
                    if (details.localPosition.dx > half) {
                      onNavigate(currentSlide + 1);
                    } else {
                      onNavigate(currentSlide - 1);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.08),
                          blurRadius: 60,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 48,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Subtle radial highlight at the top
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0, -1),
                                  radius: 1.2,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.03),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Slide content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 44,
                          ),
                          child: Center(child: child),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Navigation hint
        Text(
          '\u2190 tap pour naviguer \u2192',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

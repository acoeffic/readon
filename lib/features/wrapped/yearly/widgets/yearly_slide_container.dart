import 'package:flutter/material.dart';
import 'yearly_animations.dart';

// Per-slide radial gradients from the React mockup
const _slideGradients = <List<dynamic>>[
  [Alignment(0.0, -0.4), Color(0xFF1a1428)],  // 0: Opening
  [Alignment(-0.4, 0.0), Color(0xFF1f1020)],  // 1: Time
  [Alignment(0.4, -0.2), Color(0xFF0f1428)],  // 2: Books
  [Alignment(0.0, 0.2), Color(0xFF1a0f20)],   // 3: Genres
  [Alignment(-0.2, -0.4), Color(0xFF141028)],  // 4: Habits
  [Alignment(0.2, 0.0), Color(0xFF1f0f15)],   // 5: Top books
  [Alignment(0.0, -0.2), Color(0xFF0f1420)],  // 6: Milestones
  [Alignment(-0.4, 0.2), Color(0xFF1a1020)],  // 7: Social
  [Alignment(0.0, -0.4), Color(0xFF141020)],  // 8: Evolution
  [Alignment(0.0, 0.0), Color(0xFF1f1428)],   // 9: Final
];

/// Full-screen container for yearly wrapped slides.
class YearlySlideContainer extends StatelessWidget {
  final int currentSlide;
  final int slideCount;
  final ValueChanged<int> onNavigate;
  final VoidCallback? onClose;
  final bool isMuted;
  final VoidCallback? onToggleMute;
  final Widget child;

  const YearlySlideContainer({
    super.key,
    required this.currentSlide,
    required this.slideCount,
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

        // Header row: mute + label + close
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (onToggleMute != null)
                GestureDetector(
                  onTap: onToggleMute,
                  child: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: YearlyColors.cream.withValues(alpha: 0.3),
                    size: 20,
                  ),
                )
              else
                const SizedBox(width: 20),
              const Spacer(),
              Text(
                'YEARLY WRAPPED',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: YearlyColors.cream.withValues(alpha: 0.2),
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              if (onClose != null)
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    color: YearlyColors.cream.withValues(alpha: 0.3),
                    size: 20,
                  ),
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Golden progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: List.generate(slideCount, (i) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => onNavigate(i),
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: i < slideCount - 1 ? 3 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: i <= currentSlide
                            ? const LinearGradient(
                                colors: [YearlyColors.gold, YearlyColors.cream],
                              )
                            : null,
                        color: i > currentSlide
                            ? Colors.white.withValues(alpha: 0.12)
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),

        // Main card with starfield
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    decoration: BoxDecoration(
                      color: YearlyColors.deepBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: YearlyColors.gold.withValues(alpha: 0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: YearlyColors.gold.withValues(alpha: 0.06),
                          blurRadius: 100,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Starfield background
                        const Starfield(),

                        // Per-slide radial gradient highlight
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: currentSlide < _slideGradients.length
                                      ? _slideGradients[currentSlide][0] as Alignment
                                      : Alignment.center,
                                  radius: 1.4,
                                  colors: [
                                    currentSlide < _slideGradients.length
                                        ? (_slideGradients[currentSlide][1] as Color)
                                            .withValues(alpha: 0.7)
                                        : Colors.transparent,
                                    YearlyColors.deepBg,
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
                            vertical: 36,
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
            color: YearlyColors.cream.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

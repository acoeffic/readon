import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../yearly_animations.dart';

/// Horizontal bar for the monthly book chart (slide 2).
class MonthBar extends StatefulWidget {
  final String month;
  final int value;
  final int maxValue;
  final Duration animationDelay;

  const MonthBar({
    super.key,
    required this.month,
    required this.value,
    required this.maxValue,
    this.animationDelay = Duration.zero,
  });

  @override
  State<MonthBar> createState() => _MonthBarState();
}

class _MonthBarState extends State<MonthBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    Future.delayed(widget.animationDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        widget.maxValue > 0 ? widget.value / widget.maxValue : 0.0;

    return FadeUp(
      delay: widget.animationDelay,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              widget.month,
              textAlign: TextAlign.right,
              style: GoogleFonts.libreBaskerville(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final curve = Curves.easeOut.transform(_ctrl.value);
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction * curve,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [YearlyColors.bordeaux, YearlyColors.gold],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '${widget.value}h',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: YearlyColors.gold.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

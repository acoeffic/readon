import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../yearly_wrapped_data.dart';
import '../yearly_animations.dart';

/// Slide 6 — Milestones: timeline with emoji icons, dates and events.
class SlideMilestones extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideMilestones({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeUp(
          child: Text(
            'Moments forts',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 28),
        ...List.generate(data.milestones.length.clamp(0, 5), (i) {
          final m = data.milestones[i];
          return FadeUp(
            delay: Duration(milliseconds: 200 + i * 150),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: i < data.milestones.length - 1
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  // Emoji icon in styled box
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          YearlyColors.bordeaux.withValues(alpha: 0.25),
                          YearlyColors.gold.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(m.icon,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.dateLabel != null)
                          Text(
                            m.dateLabel!.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: YearlyColors.gold.withValues(alpha: 0.6),
                              letterSpacing: 2,
                            ),
                          ),
                        if (m.dateLabel != null) const SizedBox(height: 4),
                        Text(
                          m.title,
                          style: GoogleFonts.libreBaskerville(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

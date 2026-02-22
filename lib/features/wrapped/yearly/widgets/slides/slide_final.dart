import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../yearly_wrapped_data.dart';
import '../../../share/wrapped_share_service.dart';
import '../yearly_animations.dart';
import '../common/gold_line.dart';

/// Slide 9 — Final: "Bravo [name]" + recap + share buttons.
class SlideFinal extends StatelessWidget {
  final YearlyWrappedData data;
  const SlideFinal({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data.userName ?? 'lecteur';

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing star
          FadeUp(
            child: PulseWidget(
              child: Text('\u2726', style: GoogleFonts.libreBaskerville(
                fontSize: 56, color: YearlyColors.gold,
              )),
            ),
          ),
          const SizedBox(height: 16),

          // "Bravo Adrien"
          FadeUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'Bravo $name',
              style: GoogleFonts.libreBaskerville(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Summary line
          FadeUp(
            delay: const Duration(milliseconds: 400),
            child: Text(
              'Une annee exceptionnelle.\n'
              '${data.booksFinished} livres. '
              '${data.totalHours} heures. '
              '${data.totalSessions} sessions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4-icon recap row
          FadeUp(
            delay: const Duration(milliseconds: 600),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RecapIcon(emoji: '\uD83D\uDCD6', value: '${data.booksFinished}', label: 'livres'),
                const SizedBox(width: 16),
                _RecapIcon(emoji: '\u23F1\uFE0F', value: '${data.totalHours}h', label: 'de lecture'),
                const SizedBox(width: 16),
                _RecapIcon(emoji: '\uD83D\uDD25', value: '${data.bestFlow}j', label: 'flow'),
                const SizedBox(width: 16),
                _RecapIcon(emoji: '\uD83C\uDFC6', value: 'Top ${data.percentileRank}%', label: name),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Share button — opens the image share bottom sheet
          FadeUp(
            delay: const Duration(milliseconds: 800),
            child: GestureDetector(
              onTap: () => showWrappedShareSheet(context: context, data: data),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [YearlyColors.gold, YearlyColors.cream],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: YearlyColors.gold.withValues(alpha: 0.3),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Text(
                  'Partager mon Wrapped ${data.year}',
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: YearlyColors.deepBg,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Social links
          FadeUp(
            delay: const Duration(milliseconds: 1000),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SocialLink(label: 'Instagram', onTap: () => showWrappedShareSheet(context: context, data: data)),
                const SizedBox(width: 20),
                _SocialLink(label: 'Twitter', onTap: _shareToTwitter),
                const SizedBox(width: 20),
                _SocialLink(label: 'Copier', onTap: () => _copy(context)),
              ],
            ),
          ),

          GoldLine(width: 40, delay: const Duration(milliseconds: 1200)),
        ],
      ),
    );
  }

  String get _shareText =>
      'Mon Wrapped ${data.year} sur LexDay :\n'
      '${data.formattedTotalTime} de lecture\n'
      '${data.booksFinished} livres termines\n'
      '${data.bestFlow} jours de flow !\n'
      'Top ${data.percentileRank}% des lecteurs';

  void _shareToTwitter() {
    final encoded = Uri.encodeComponent(_shareText);
    launchUrl(
      Uri.parse('https://twitter.com/intent/tweet?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shareText)).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Copie dans le presse-papier !'),
            backgroundColor: YearlyColors.gold.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }
}

class _RecapIcon extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _RecapIcon({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: YearlyColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SocialLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

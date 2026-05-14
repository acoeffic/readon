// pages/feed/widgets/wrapped_banner.dart
// Bannière du feed permettant de ré-ouvrir le Wrapped mensuel pendant 24 h
// après réception de la notification. Style festif "Wrapped" :
// gradient vibrant, sparkles décoratifs et léger glow animé.

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class WrappedBanner extends StatefulWidget {
  final int month;
  final int year;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const WrappedBanner({
    super.key,
    required this.month,
    required this.year,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<WrappedBanner> createState() => _WrappedBannerState();
}

class _WrappedBannerState extends State<WrappedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    // Pulsation lente du glow (1.5 s aller-retour) — discret mais vivant.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  // Noms de mois en dur (l'app n'appelle pas `initializeDateFormatting`).
  static const _monthsFr = [
    '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const _monthsEn = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthsEs = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Retourne le label de mois localisé, déjà préfixé pour la langue
  /// courante. En FR : élision "d'avril" / "de mars" pour s'intégrer dans
  /// "Ton Wrapped {label} est là".
  String _monthLabel(BuildContext context) {
    if (widget.month < 1 || widget.month > 12) return '';
    final code = Localizations.localeOf(context).languageCode;
    switch (code) {
      case 'fr':
        final m = _monthsFr[widget.month];
        return _frenchPrefix(m);
      case 'es':
        // En espagnol, on dit "Wrapped de abril" — le "de" est invariable.
        return 'de ${_monthsEs[widget.month]}';
      default:
        return _monthsEn[widget.month];
    }
  }

  String _frenchPrefix(String month) {
    if (month.isEmpty) return month;
    final first = month[0].toLowerCase();
    const vowels = {'a', 'e', 'i', 'o', 'u', 'h', 'é', 'è', 'à'};
    return vowels.contains(first) ? "d'$month" : 'de $month';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final monthLabel = _monthLabel(context);

    // Palette LexDay : sage green → or doré, en miroir de l'écran Wrapped.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [
            Color(0xFF1A4D44), // accentDark — sage profond
            Color(0xFF6B988D), // sageGreen
            Color(0xFFC6A85A), // gold
          ]
        : const [
            Color(0xFF6B988D), // sageGreen
            Color(0xFF7FA497), // primary
            Color(0xFFC6A85A), // gold
          ];

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final glowAlpha = 0.20 + 0.18 * _glow.value; // 0.20 → 0.38
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.l),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC6A85A).withValues(alpha: glowAlpha),
                blurRadius: 22,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.l),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                splashColor: Colors.white.withValues(alpha: 0.15),
                highlightColor: Colors.white.withValues(alpha: 0.08),
                child: Stack(
                  children: [
                    // Gradient de fond
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Sparkles décoratifs en fond
                    const Positioned(
                      top: 6,
                      right: 60,
                      child: Text(
                        '✨',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const Positioned(
                      bottom: 6,
                      left: 70,
                      child: Opacity(
                        opacity: 0.6,
                        child: Text(
                          '✨',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 110,
                      child: Opacity(
                        opacity: 0.5,
                        child: Text(
                          '⭐',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    // Contenu
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.l,
                        AppSpace.m,
                        AppSpace.xs,
                        AppSpace.m,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Emoji avec halo
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '🎉',
                              style: TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.wrappedBannerTitle(monthLabel),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x66000000),
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.wrappedBannerSubtitle,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          // Pill "VOIR" — fond crème, texte sage green LexDay
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF3E8), // libraryBg
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '✨',
                                  style: TextStyle(fontSize: 11),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'VOIR',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6B988D), // sageGreen
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Bouton fermer
                          IconButton(
                            onPressed: widget.onDismiss,
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            tooltip: l10n.wrappedBannerDismiss,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

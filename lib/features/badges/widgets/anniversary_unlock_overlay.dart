// lib/features/badges/widgets/anniversary_unlock_overlay.dart

import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/anniversary_badge.dart';
import 'anniversary_badge_painter.dart';
import 'particle_painter.dart';

/// Overlay plein écran pour l'unlock d'un badge anniversaire.
/// 5 phases : Teaser → Burst → Reveal → Stats → Actions
class AnniversaryUnlockOverlay extends StatefulWidget {
  final AnniversaryBadge badge;
  final AnniversaryStats stats;
  final VoidCallback onDismiss;

  const AnniversaryUnlockOverlay({
    super.key,
    required this.badge,
    required this.stats,
    required this.onDismiss,
  });

  /// Afficher l'overlay via showGeneralDialog
  static Future<void> show(
    BuildContext context, {
    required AnniversaryBadge badge,
    required AnniversaryStats stats,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => AnniversaryUnlockOverlay(
        badge: badge,
        stats: stats,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<AnniversaryUnlockOverlay> createState() =>
      _AnniversaryUnlockOverlayState();
}

class _AnniversaryUnlockOverlayState extends State<AnniversaryUnlockOverlay>
    with TickerProviderStateMixin {
  // Phase tracking
  int _currentPhase = 0;

  // Phase 0 : Teaser — anneau pulsant
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Phase 1 : Burst — explosion de particules
  late AnimationController _burstController;
  late List<ParticleData> _particles;

  // Phase 2 : Badge reveal — scale + rotation
  late AnimationController _revealController;
  late Animation<double> _revealScale;
  late Animation<double> _revealRotation;

  // Phase 3 : Stats — staggered fade up
  late AnimationController _statsController;

  // Phase 4 : Actions — fade in
  late AnimationController _actionsController;

  // Premium shimmer (continu)
  AnimationController? _shimmerController;

  // Gift scale-out quand on tape
  late AnimationController _giftExitController;
  late Animation<double> _giftExitScale;

  final _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();

    // Générer les particules
    _particles = generateParticles(
      primaryColor: widget.badge.primaryColor,
      secondaryColor: widget.badge.secondaryColor,
    );

    // Phase 0 : Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Gift exit
    _giftExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _giftExitScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _giftExitController, curve: Curves.easeIn),
    );

    // Phase 1 : Burst
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _burstController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startPhase2();
      }
    });

    // Phase 2 : Reveal
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _revealScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_revealController);

    _revealRotation = Tween<double>(
      begin: -math.pi,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startPhase3();
      }
    });

    // Phase 3 : Stats
    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _statsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startPhase4();
      }
    });

    // Phase 4 : Actions
    _actionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Shimmer premium
    if (widget.badge.isPremium) {
      _shimmerController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat();
    }
  }

  void _onTeaserTap() {
    if (_currentPhase != 0) return;
    setState(() => _currentPhase = 1);
    _giftExitController.forward();
    // Démarrer le burst après que le cadeau disparaisse
    Future.delayed(const Duration(milliseconds: 150), () {
      _burstController.forward();
    });
  }

  void _startPhase2() {
    if (!mounted) return;
    setState(() => _currentPhase = 2);
    _revealController.forward();
  }

  void _startPhase3() {
    if (!mounted) return;
    setState(() => _currentPhase = 3);
    _statsController.forward();
  }

  void _startPhase4() {
    if (!mounted) return;
    setState(() => _currentPhase = 4);
    _actionsController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _burstController.dispose();
    _revealController.dispose();
    _statsController.dispose();
    _actionsController.dispose();
    _shimmerController?.dispose();
    _giftExitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fond avec blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Contenu centré
          Positioned.fill(
            child: SafeArea(
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return GestureDetector(
      onTap: _currentPhase == 0 ? _onTeaserTap : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Zone centrale : cadeau / particules / badge
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Phase 1 : Particules (burst)
                if (_currentPhase >= 1)
                  AnimatedBuilder(
                    animation: _burstController,
                    builder: (_, __) => CustomPaint(
                      size: const Size(280, 280),
                      painter: ParticlePainter(
                        progress: _burstController.value,
                        particles: _particles,
                      ),
                    ),
                  ),

                // Phase 0 : Cadeau pulsant
                if (_currentPhase <= 1)
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_pulseAnimation, _giftExitScale]),
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnimation.value * _giftExitScale.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade700,
                          border: Border.all(
                            color: widget.badge.primaryColor
                                .withValues(alpha: 0.6),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.badge.primaryColor
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🎁',
                              style: TextStyle(fontSize: 42)),
                        ),
                      ),
                    ),
                  ),

                // Phase 2+ : Badge
                if (_currentPhase >= 2)
                  AnimatedBuilder(
                    animation: _revealController,
                    builder: (_, __) {
                      final shimmerValue =
                          _shimmerController?.value ?? 0.0;
                      return Transform.scale(
                        scale: _revealScale.value,
                        child: Transform.rotate(
                          angle: _revealRotation.value,
                          child: SizedBox(
                            width: 180,
                            height: 180,
                            child: CustomPaint(
                              painter: AnniversaryBadgePainter(
                                primaryColor:
                                    widget.badge.primaryColor,
                                secondaryColor:
                                    widget.badge.secondaryColor,
                                ringColor: widget.badge.ringColor,
                                years: widget.badge.years,
                                isPremium: widget.badge.isPremium,
                                shimmerProgress: shimmerValue,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Textes selon la phase
          if (_currentPhase == 0) ...[
            Text(
              'Tu as un nouveau badge !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Appuie pour le découvrir',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onTeaserTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B988D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Découvrir ✨',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          // Phase 3+ : Badge info + stats
          if (_currentPhase >= 2) ...[
            _buildBadgeInfo(),
          ],

          if (_currentPhase >= 3) ...[
            const SizedBox(height: 16),
            _buildStats(),
          ],

          const Spacer(flex: 1),

          // Phase 4 : Boutons d'action
          if (_currentPhase >= 4) _buildActions(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBadgeInfo() {
    return AnimatedBuilder(
      animation: _revealController,
      builder: (_, __) {
        final opacity =
            Curves.easeIn.transform((_revealController.value - 0.5)
                .clamp(0.0, 1.0) * 2);
        return Opacity(
          opacity: opacity,
          child: Column(
            children: [
              Text(
                '🎉 BADGE DÉBLOQUÉ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.badge.primaryColor,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.badge.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.badge.ringColor,
                  fontFamily: 'Georgia',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.badge.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    final stats = [
      _StatItem(
          emoji: '📚',
          value: widget.stats.booksFinished,
          label: widget.stats.booksFinished <= 1
              ? 'livre lu'
              : 'livres lus'),
      _StatItem(
          emoji: '⏱',
          value: widget.stats.hoursRead,
          label: 'h de lecture'),
      _StatItem(
          emoji: '🔥',
          value: widget.stats.bestFlow,
          label: widget.stats.bestFlow <= 1
              ? 'jour consécutif'
              : 'jours consécutifs max'),
      _StatItem(
          emoji: '💬',
          value: widget.stats.commentsCount,
          label: widget.stats.commentsCount <= 1
              ? 'commentaire'
              : 'commentaires'),
    ];

    return AnimatedBuilder(
      animation: _statsController,
      builder: (_, __) {
        return Column(
          children: List.generate(stats.length, (index) {
            // Stagger : chaque stat apparaît avec 150ms de décalage
            final startFraction = index * 0.15;
            final endFraction = (startFraction + 0.4).clamp(0.0, 1.0);
            final interval = Interval(
              startFraction,
              endFraction,
              curve: Curves.easeOut,
            );
            final progress =
                interval.transform(_statsController.value);

            return Transform.translate(
              offset: Offset(0, 20 * (1 - progress)),
              child: Opacity(
                opacity: progress,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 3, horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(stats[index].emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        '${stats[index].value}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          stats[index].label,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildActions() {
    return AnimatedBuilder(
      animation: _actionsController,
      builder: (_, __) {
        return Opacity(
          opacity: _actionsController.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Partager
                ElevatedButton(
                  onPressed: _onShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.badge.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Partager 🎉',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 16),
                // Fermer
                OutlinedButton(
                  onPressed: widget.onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onShare() async {
    try {
      final bytes = await _screenshotController.captureFromWidget(
        _AnniversaryShareCard(
          badge: widget.badge,
          stats: widget.stats,
        ),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 200),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/readon_anniversary_${widget.badge.years}ans.png');
      await file.writeAsBytes(bytes);

      final yearsText = widget.badge.years == 1
          ? '1 an'
          : '${widget.badge.years} ans';

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '$yearsText sur ReadOn ! ${widget.badge.icon} #ReadOn',
      );
    } catch (e) {
      debugPrint('Erreur partage badge anniversaire: $e');
    }
  }
}

// ─────────────────────────────────────────────
// Data class pour les stats
// ─────────────────────────────────────────────

class _StatItem {
  final String emoji;
  final int value;
  final String label;

  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
  });
}

// ─────────────────────────────────────────────
// Share card (capturée en screenshot pour le partage)
// ─────────────────────────────────────────────

class _AnniversaryShareCard extends StatelessWidget {
  final AnniversaryBadge badge;
  final AnniversaryStats stats;

  const _AnniversaryShareCard({
    required this.badge,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badge.primaryColor.withValues(alpha: 0.15),
            badge.secondaryColor.withValues(alpha: 0.1),
            const Color(0xFF1A1A2E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: AnniversaryBadgePainter(
                primaryColor: badge.primaryColor,
                secondaryColor: badge.secondaryColor,
                ringColor: badge.ringColor,
                years: badge.years,
                isPremium: badge.isPremium,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Titre
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: badge.primaryColor,
              fontFamily: 'Georgia',
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            badge.description,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareStat(
                  emoji: '📚', value: '${stats.booksFinished}', label: 'livres'),
              _ShareStat(
                  emoji: '⏱', value: '${stats.hoursRead}h', label: 'lecture'),
              _ShareStat(
                  emoji: '🔥', value: '${stats.bestFlow}', label: 'jours'),
            ],
          ),

          const SizedBox(height: 20),

          // Branding
          Text(
            'ReadOn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _ShareStat({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

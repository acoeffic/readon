// lib/widgets/badge_display.dart
// Widget d'affichage de badge SVG avec effets animés :
// 1. Float (lévitation)  2. Glow pulsé  3. Shimmer diagonal
// 4. Particules dorées   5. Burst au tap (déblocage)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BadgeDisplay extends StatefulWidget {
  /// Chemin de base du SVG (sans _light.svg / _dark.svg).
  /// Ex: 'assets/badges/badge_books_10'
  /// Supporte aussi les URLs réseau (commence par http).
  final String svgBasePath;

  /// Taille du badge (largeur = hauteur).
  final double size;

  /// false = statique (pour grilles, listes).
  final bool animate;

  /// true = jouer le burst de déblocage au premier build.
  final bool showUnlockBurst;

  /// Couleur du tier en mode light (glow, particules, burst).
  final Color tierColorLight;

  /// Couleur du tier en mode dark.
  final Color tierColorDark;

  const BadgeDisplay({
    super.key,
    required this.svgBasePath,
    this.size = 120,
    this.animate = true,
    this.showUnlockBurst = false,
    this.tierColorLight = const Color(0xFFA07A0A),
    this.tierColorDark = const Color(0xFFD4A017),
  });

  @override
  State<BadgeDisplay> createState() => _BadgeDisplayState();
}

class _BadgeDisplayState extends State<BadgeDisplay>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  late final AnimationController _floatCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particlesCtrl;
  AnimationController? _burstCtrl;

  // ── Animations ───────────────────────────────────────────────
  late final Animation<double> _floatAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _particlesAnim;
  Animation<double>? _burstAnim;

  // ── Particule positions (8 points fixes, générés une seule fois) ──
  late final List<_Particle> _particles;

  // ── Thème (mis à jour dans didChangeDependencies) ───────────
  bool _isDark = false;

  @override
  void initState() {
    super.initState();

    // 1. Float : 5 s, ease-in-out, boucle
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // 2. Glow : 4 s, boucle
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // 3. Shimmer : 5 s, boucle
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _shimmerAnim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );

    // 4. Particules : 6 s, boucle
    _particlesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _particlesAnim = Tween<double>(begin: 0, end: 1).animate(_particlesCtrl);

    // Générer 8 particules avec des positions et delays aléatoires
    final rng = math.Random(42);
    _particles = List.generate(8, (i) {
      final angle = (i / 8) * 2 * math.pi + rng.nextDouble() * 0.5;
      final dist = 0.35 + rng.nextDouble() * 0.15;
      return _Particle(
        angle: angle,
        distanceFactor: dist,
        delay: i * 0.12,
        sizePx: 2.0 + rng.nextDouble(),
      );
    });

    if (widget.animate) {
      _startAnimations();
    }

    // 5. Burst (optionnel)
    if (widget.showUnlockBurst) {
      _triggerBurst();
    }
  }

  void _startAnimations() {
    _floatCtrl.repeat(reverse: true);
    _glowCtrl.repeat(reverse: true);
    _shimmerCtrl.repeat();
    _particlesCtrl.repeat();
  }

  void _stopAnimations() {
    _floatCtrl.stop();
    _glowCtrl.stop();
    _shimmerCtrl.stop();
    _particlesCtrl.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newIsDark = Theme.of(context).brightness == Brightness.dark;
    if (newIsDark != _isDark) {
      _isDark = newIsDark;
    }
  }

  @override
  void didUpdateWidget(covariant BadgeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _startAnimations();
    } else if (!widget.animate && oldWidget.animate) {
      _stopAnimations();
    }
    if (widget.showUnlockBurst && !oldWidget.showUnlockBurst) {
      _triggerBurst();
    }
  }

  void _triggerBurst() {
    _burstCtrl?.dispose();
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _burstAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _burstCtrl!, curve: Curves.easeOut),
    );
    _burstCtrl!.forward();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    _particlesCtrl.dispose();
    _burstCtrl?.dispose();
    super.dispose();
  }

  // ── Couleurs adaptées au thème ───────────────────────────────
  Color get _tierColor =>
      _isDark ? widget.tierColorDark : widget.tierColorLight;

  double get _glowOpacityMin => _isDark ? 0.15 : 0.08;
  double get _glowOpacityMax => _isDark ? 0.35 : 0.18;
  double get _shimmerOpacityMin => _isDark ? 0.06 : 0.3;
  double get _shimmerOpacityMax => _isDark ? 0.14 : 0.6;
  double get _particleOpacityMax => _isDark ? 0.6 : 0.4;

  Color get _particleColor =>
      _isDark ? const Color(0xFFF0C840) : const Color(0xFFB8920E);

  Color get _burstColor =>
      _isDark ? const Color(0xFFF0C840) : const Color(0xFFA07A0A);

  String get _svgPath =>
      '${widget.svgBasePath}_${_isDark ? 'dark' : 'light'}.svg';

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _triggerBurst,
        child: SizedBox(
          width: s,
          height: s,
          child: widget.animate
              ? AnimatedBuilder(
                  listenable: Listenable.merge([
                    _floatCtrl,
                    _glowCtrl,
                    _shimmerCtrl,
                    _particlesCtrl,
                    if (_burstCtrl != null) _burstCtrl!,
                  ]),
                  builder: (context, child) => _buildStack(s),
                )
              : _buildStaticStack(s),
        ),
      ),
    );
  }

  Widget _buildStaticStack(double s) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildSvg(s),
      ],
    );
  }

  Widget _buildStack(double s) {
    final floatY = _floatAnim.value;

    return Transform.translate(
      offset: Offset(0, floatY),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer 1 : Glow pulsé
          _buildGlow(s),
          // Layer 2 : SVG badge
          _buildSvg(s),
          // Layer 3 : Shimmer diagonal
          _buildShimmer(s),
          // Layer 4 : Particules dorées
          _buildParticles(s),
          // Layer 5 : Burst
          if (_burstCtrl != null && _burstCtrl!.isAnimating)
            _buildBurst(s),
        ],
      ),
    );
  }

  // ── Layer 1 : Glow ────────────────────────────────────────────
  Widget _buildGlow(double s) {
    final opacity =
        _glowOpacityMin + (_glowOpacityMax - _glowOpacityMin) * _glowAnim.value;

    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _tierColor.withValues(alpha: opacity),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }

  // ── Layer 2 : SVG ─────────────────────────────────────────────
  Widget _buildSvg(double s) {
    final path = _svgPath;
    final isNetwork = path.startsWith('http');
    return SizedBox(
      width: s * 0.75,
      height: s * 0.75,
      child: isNetwork
          ? SvgPicture.network(
              path,
              width: s * 0.75,
              height: s * 0.75,
              fit: BoxFit.contain,
            )
          : SvgPicture.asset(
              path,
              width: s * 0.75,
              height: s * 0.75,
              fit: BoxFit.contain,
            ),
    );
  }

  // ── Layer 3 : Shimmer diagonal ────────────────────────────────
  Widget _buildShimmer(double s) {
    final t = _shimmerAnim.value; // -1 → 2
    final opacityMin = _shimmerOpacityMin;
    final opacityMax = _shimmerOpacityMax;
    // Fade in → peak → fade out  (triangle entre t=0 et t=1)
    final normalT = t.clamp(0.0, 1.0);
    final shimmerOpacity =
        opacityMin + (opacityMax - opacityMin) * (1 - (2 * normalT - 1).abs());

    return ClipOval(
      child: SizedBox(
        width: s * 0.75,
        height: s * 0.75,
        child: Transform.rotate(
          angle: 25 * math.pi / 180, // ~25°
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: shimmerOpacity),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: [
                  (t - 0.3).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              color: Colors.white.withValues(alpha: shimmerOpacity * 0.5),
            ),
          ),
        ),
      ),
    );
  }

  // ── Layer 4 : Particules dorées (8 points) ────────────────────
  Widget _buildParticles(double s) {
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          progress: _particlesAnim.value,
          color: _particleColor,
          maxOpacity: _particleOpacityMax,
          badgeSize: s,
        ),
      ),
    );
  }

  // ── Layer 5 : Burst au tap ────────────────────────────────────
  Widget _buildBurst(double s) {
    final t = _burstAnim!.value;
    final scale = 0.5 + t; // 0.5 → 1.5
    final opacity = (1 - t).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: s * 0.75,
        height: s * 0.75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _burstColor.withValues(alpha: opacity * 0.6),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: _burstColor.withValues(alpha: opacity * 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modèle de particule ──────────────────────────────────────────
class _Particle {
  final double angle;
  final double distanceFactor;
  final double delay;
  final double sizePx;

  const _Particle({
    required this.angle,
    required this.distanceFactor,
    required this.delay,
    required this.sizePx,
  });
}

// ── Painter pour les 8 particules ────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0 → 1
  final Color color;
  final double maxOpacity;
  final double badgeSize;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.maxOpacity,
    required this.badgeSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = badgeSize * 0.35;

    for (final p in particles) {
      // Chaque particule a son propre cycle décalé
      final t = ((progress + p.delay) % 1.0);

      // Fade in → monte 8px → fade out
      // Phase 0–0.3 : fade in, 0.3–0.7 : visible, 0.7–1.0 : fade out
      double opacity;
      if (t < 0.3) {
        opacity = (t / 0.3) * maxOpacity;
      } else if (t < 0.7) {
        opacity = maxOpacity;
      } else {
        opacity = ((1 - t) / 0.3) * maxOpacity;
      }

      // Déplacement vertical : monte de 8px pendant le cycle
      final yOffset = -8 * t;

      final dist = radius * p.distanceFactor / 0.5;
      final dx = center.dx + math.cos(p.angle) * dist;
      final dy = center.dy + math.sin(p.angle) * dist + yOffset;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), p.sizePx, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ── AnimatedBuilder alias (utilise le standard AnimatedBuilder) ──
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}

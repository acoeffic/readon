// lib/features/badges/widgets/particle_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Type de particule pour l'explosion de burst
enum ParticleType { circle, leaf, square, bookPage }

/// Données pré-générées pour une particule
class ParticleData {
  final double angle; // direction en radians
  final double distance; // distance max depuis le centre (px)
  final double size; // taille de la particule (px)
  final Color color;
  final ParticleType type;
  final double rotationSpeed; // vitesse de rotation

  const ParticleData({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.type,
    required this.rotationSpeed,
  });
}

/// Génère la liste des particules pour l'explosion
List<ParticleData> generateParticles({
  required Color primaryColor,
  required Color secondaryColor,
}) {
  final rng = math.Random();
  final particles = <ParticleData>[];

  final colors = [
    primaryColor,
    secondaryColor,
    const Color(0xFFE8D8C4),
    const Color(0xFFC4B89A),
    Colors.white,
  ];

  // 35 petites particules
  for (int i = 0; i < 35; i++) {
    final typeIndex = rng.nextInt(3);
    final type = [ParticleType.circle, ParticleType.leaf, ParticleType.square][typeIndex];

    particles.add(ParticleData(
      angle: rng.nextDouble() * 2 * math.pi,
      distance: 100 + rng.nextDouble() * 160,
      size: 4 + rng.nextDouble() * 7,
      color: colors[rng.nextInt(colors.length)],
      type: type,
      rotationSpeed: (rng.nextDouble() - 0.5) * 6,
    ));
  }

  // 7 pages de livre
  for (int i = 0; i < 7; i++) {
    particles.add(ParticleData(
      angle: rng.nextDouble() * 2 * math.pi,
      distance: 80 + rng.nextDouble() * 140,
      size: 12 + rng.nextDouble() * 8,
      color: const Color(0xFFF5EDE0),
      type: ParticleType.bookPage,
      rotationSpeed: (rng.nextDouble() - 0.5) * 8,
    ));
  }

  return particles;
}

/// CustomPainter pour l'explosion de particules (Phase 2)
class ParticlePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final List<ParticleData> particles;

  ParticlePainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Halo expansif central
    _drawHalo(canvas, center, size);

    // Particules
    for (final p in particles) {
      _drawParticle(canvas, center, p);
    }
  }

  void _drawHalo(Canvas canvas, Offset center, Size size) {
    if (progress > 0.8) return; // Le halo disparaît après 80%

    final haloProgress = (progress / 0.8).clamp(0.0, 1.0);
    final haloRadius = size.width * 0.5 * haloProgress;
    final haloOpacity = (1.0 - haloProgress) * 0.3;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: haloOpacity),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: center, radius: haloRadius));

    canvas.drawCircle(center, haloRadius, haloPaint);
  }

  void _drawParticle(Canvas canvas, Offset center, ParticleData p) {
    // Position : du centre vers l'extérieur
    final currentDistance = p.distance * progress;
    final x = center.dx + currentDistance * math.cos(p.angle);
    final y = center.dy + currentDistance * math.sin(p.angle);

    // Scale : 1 → 0 progressivement
    final scale = (1.0 - progress).clamp(0.0, 1.0);
    // Opacity : fade out
    final opacity = (1.0 - progress * progress).clamp(0.0, 1.0);

    if (opacity <= 0 || scale <= 0) return;

    final paint = Paint()
      ..color = p.color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(p.rotationSpeed * progress * math.pi);
    canvas.scale(scale);

    switch (p.type) {
      case ParticleType.circle:
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
        break;

      case ParticleType.leaf:
        // Feuille : borderRadius asymétrique
        final leafPath = Path()
          ..moveTo(0, -p.size / 2)
          ..quadraticBezierTo(
              p.size / 2, -p.size / 4, p.size / 3, p.size / 4)
          ..quadraticBezierTo(0, p.size / 2, -p.size / 3, p.size / 4)
          ..quadraticBezierTo(
              -p.size / 2, -p.size / 4, 0, -p.size / 2)
          ..close();
        canvas.drawPath(leafPath, paint);
        break;

      case ParticleType.square:
        final half = p.size / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
            Radius.circular(half * 0.2),
          ),
          paint,
        );
        break;

      case ParticleType.bookPage:
        // Rectangle beige avec "lignes" grises
        final w = p.size;
        final h = p.size * 1.4;
        final rect =
            Rect.fromCenter(center: Offset.zero, width: w, height: h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );

        // Lignes grises sur la page
        final linePaint = Paint()
          ..color = Colors.grey.withValues(alpha: opacity * 0.4)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;

        for (int i = 1; i <= 3; i++) {
          final ly = rect.top + (rect.height / 4) * i;
          canvas.drawLine(
            Offset(rect.left + 2, ly),
            Offset(rect.right - 2, ly),
            linePaint,
          );
        }
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

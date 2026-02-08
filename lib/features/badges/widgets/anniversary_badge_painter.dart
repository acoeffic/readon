// lib/features/badges/widgets/anniversary_badge_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnniversaryBadgePainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color ringColor;
  final int years;
  final bool isPremium;
  final double shimmerProgress; // 0.0–1.0 pour les particules premium

  AnniversaryBadgePainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.ringColor,
    required this.years,
    required this.isPremium,
    this.shimmerProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Glow radial
    _drawGlow(canvas, center, radius);

    // 2. Anneau cranté
    _drawCrenellatedRing(canvas, center, radius);

    // 3. Cercle intérieur avec gradient
    _drawInnerCircle(canvas, center, radius);

    // 4. Cercle décoratif intérieur
    _drawDecorativeCircle(canvas, center, radius);

    // 5. Numéro de l'année
    _drawYearNumber(canvas, center, size);

    // 6. "AN" / "ANS"
    _drawYearLabel(canvas, center, size);

    // 7. Points décoratifs
    _drawDecorativeDots(canvas, center, radius);

    // 8. Particules scintillantes (premium uniquement)
    if (isPremium) {
      _drawSparkles(canvas, center, radius);
    }
  }

  void _drawGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.3),
          primaryColor.withValues(alpha: 0.0),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));

    canvas.drawCircle(center, radius * 1.3, glowPaint);
  }

  void _drawCrenellatedRing(Canvas canvas, Offset center, double radius) {
    final crenCount = 28 + years * 4;
    final outerRadius = radius * 0.92;
    final innerRadius = radius * 0.78;
    final path = Path();

    for (int i = 0; i < crenCount * 2; i++) {
      final angle = (i * math.pi) / crenCount;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + r * math.cos(angle - math.pi / 2);
      final y = center.dy + r * math.sin(angle - math.pi / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, ringPaint);
  }

  void _drawInnerCircle(Canvas canvas, Offset center, double radius) {
    final innerRadius = radius * 0.72;

    // Stroke secondaire
    final strokePaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, innerRadius + 1.5, strokePaint);

    // Gradient radial face du médaillon
    final facePaint = Paint()
      ..shader = RadialGradient(
        colors: [secondaryColor, primaryColor],
        stops: const [0.0, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: innerRadius));

    canvas.drawCircle(center, innerRadius, facePaint);
  }

  void _drawDecorativeCircle(Canvas canvas, Offset center, double radius) {
    final decoRadius = radius * 0.58;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    if (years >= 3) {
      // Cercle pointillé pour 3+ ans
      const dashCount = 36;
      for (int i = 0; i < dashCount; i++) {
        if (i.isEven) {
          final startAngle = (i * 2 * math.pi) / dashCount;
          final sweepAngle = (2 * math.pi) / dashCount;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: decoRadius),
            startAngle,
            sweepAngle,
            false,
            paint,
          );
        }
      }
    } else {
      canvas.drawCircle(center, decoRadius, paint);
    }
  }

  void _drawYearNumber(Canvas canvas, Offset center, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$years',
        style: TextStyle(
          fontSize: size.width * 0.30,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Georgia',
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - size.width * 0.04,
      ),
    );
  }

  void _drawYearLabel(Canvas canvas, Offset center, Size size) {
    final label = years == 1 ? 'AN' : 'ANS';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: size.width * 0.09,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
          letterSpacing: 3,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + size.width * 0.14,
      ),
    );
  }

  void _drawDecorativeDots(Canvas canvas, Offset center, double radius) {
    int dotCount;
    if (years <= 2) {
      dotCount = 4;
    } else if (years <= 4) {
      dotCount = 6;
    } else {
      dotCount = 8;
    }

    final dotRadius = radius * 0.65;
    final dotSize = radius * 0.025;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * math.pi) / dotCount - math.pi / 2;
      final x = center.dx + dotRadius * math.cos(angle);
      final y = center.dy + dotRadius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
    }
  }

  void _drawSparkles(Canvas canvas, Offset center, double radius) {
    final rng = math.Random(42);
    const sparkleCount = 8;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final dist = radius * (0.5 + rng.nextDouble() * 0.35);
      final x = center.dx + dist * math.cos(angle);
      final y = center.dy + dist * math.sin(angle);

      // Chaque sparkle a un cycle de phase décalé
      final phase = (shimmerProgress + i / sparkleCount) % 1.0;
      final opacity = (math.sin(phase * 2 * math.pi) * 0.5 + 0.5) * 0.8;

      final size = radius * (0.02 + rng.nextDouble() * 0.02);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Dessiner une étoile à 4 branches
      final path = Path();
      for (int j = 0; j < 8; j++) {
        final a = j * math.pi / 4;
        final r = j.isEven ? size * 2.5 : size * 0.8;
        final px = x + r * math.cos(a);
        final py = y + r * math.sin(a);
        if (j == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnniversaryBadgePainter oldDelegate) {
    return oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.years != years ||
        oldDelegate.primaryColor != primaryColor;
  }
}

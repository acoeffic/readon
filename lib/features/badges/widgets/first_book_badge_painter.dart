// lib/features/badges/widgets/first_book_badge_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class FirstBookBadgePainter extends CustomPainter {
  static const Color primary = Color(0xFF6B988D);
  static const Color secondary = Color(0xFFA8C5B8);
  static const Color ring = Color(0xFF5A8377);

  const FirstBookBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Glow extérieur
    _drawGlow(canvas, center, radius);

    // 2. Anneau cranté
    _drawNotchedRing(canvas, center, radius);

    // 3. Cercle intérieur (fond)
    _drawInnerCircleBackground(canvas, center, radius);

    // 4. Face du médaillon (gradient)
    _drawMedallionFace(canvas, center, radius);

    // 5. Cercle décoratif
    _drawDecorativeCircle(canvas, center, radius);

    // 6. Icône livre ouvert
    _drawOpenBook(canvas, center, radius);

    // 7. Labels texte ("1er" en haut, "LIVRE" en bas)
    _drawLabels(canvas, center, size);

    // 8. Points décoratifs
    _drawDecorativeDots(canvas, center, radius);
  }

  void _drawGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.35),
          primary.withValues(alpha: 0.0),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, glowPaint);
  }

  void _drawNotchedRing(Canvas canvas, Offset center, double radius) {
    final outerRadius = radius * 0.92;
    final innerRadius = radius * 0.78;
    final path = Path();

    const int notches = 36;
    for (int i = 0; i < notches; i++) {
      final angle = (i / notches) * 2 * math.pi - math.pi / 2;
      final rad = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + rad * math.cos(angle);
      final y = center.dy + rad * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = ring.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Ring
    canvas.drawPath(
      path,
      Paint()
        ..color = ring
        ..style = PaintingStyle.fill,
    );
  }

  void _drawInnerCircleBackground(
      Canvas canvas, Offset center, double radius) {
    final innerRadius = radius * 0.72;

    // Bordure secondary
    canvas.drawCircle(
      center,
      innerRadius + 1.5,
      Paint()
        ..color = secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Fond avec opacité
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()..color = primary.withValues(alpha: 0.92),
    );
  }

  void _drawMedallionFace(Canvas canvas, Offset center, double radius) {
    final innerRadius = radius * 0.72;

    // Gradient radial décalé (centre à 38%, 32%)
    final gradientCenter = Offset(
      center.dx - innerRadius * 0.24, // décalé vers la gauche (38% = 0.5-0.12)
      center.dy - innerRadius * 0.36, // décalé vers le haut (32% = 0.5-0.18)
    );

    final facePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (gradientCenter.dx - center.dx) / innerRadius,
          (gradientCenter.dy - center.dy) / innerRadius,
        ),
        colors: [secondary, primary],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));

    canvas.drawCircle(center, innerRadius, facePaint);
  }

  void _drawDecorativeCircle(Canvas canvas, Offset center, double radius) {
    final decoRadius = radius * 0.58;
    canvas.drawCircle(
      center,
      decoRadius,
      Paint()
        ..color = ring.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  void _drawOpenBook(Canvas canvas, Offset center, double radius) {
    final bookSize = radius * 0.38;
    final bookTop = center.dy - bookSize * 0.35;
    final bookBottom = center.dy + bookSize * 0.55;

    // Page gauche
    final leftPage = Path()
      ..moveTo(center.dx, bookTop)
      ..quadraticBezierTo(
        center.dx - bookSize * 0.7,
        bookTop + bookSize * 0.1,
        center.dx - bookSize * 0.65,
        bookBottom,
      )
      ..lineTo(center.dx, bookBottom - bookSize * 0.05)
      ..close();

    // Gradient pour page gauche
    final leftPagePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFDF7),
          const Color(0xFFF5EFE3),
        ],
      ).createShader(Rect.fromLTRB(
        center.dx - bookSize * 0.7,
        bookTop,
        center.dx,
        bookBottom,
      ));
    canvas.drawPath(leftPage, leftPagePaint);

    // Page droite
    final rightPage = Path()
      ..moveTo(center.dx, bookTop)
      ..quadraticBezierTo(
        center.dx + bookSize * 0.7,
        bookTop + bookSize * 0.1,
        center.dx + bookSize * 0.65,
        bookBottom,
      )
      ..lineTo(center.dx, bookBottom - bookSize * 0.05)
      ..close();

    final rightPagePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xFFFFFDF7),
          const Color(0xFFF5EFE3),
        ],
      ).createShader(Rect.fromLTRB(
        center.dx,
        bookTop,
        center.dx + bookSize * 0.7,
        bookBottom,
      ));
    canvas.drawPath(rightPage, rightPagePaint);

    // Ligne de reliure centrale
    canvas.drawLine(
      Offset(center.dx, bookTop + bookSize * 0.05),
      Offset(center.dx, bookBottom - bookSize * 0.1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    // Lignes de texte simulées — page gauche
    final textLinePaint = Paint()
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    final lineStartX = center.dx - bookSize * 0.5;
    final lineEndX = center.dx - bookSize * 0.1;
    final lineSpacing = bookSize * 0.15;
    final firstLineY = bookTop + bookSize * 0.35;

    const leftOpacities = [0.3, 0.25, 0.2, 0.15];
    for (int i = 0; i < 4; i++) {
      final y = firstLineY + i * lineSpacing;
      // Ajuster la longueur de chaque ligne (courbe de la page)
      final progress = i / 3.0;
      final curveOffset = bookSize * 0.08 * progress;
      textLinePaint.color = primary.withValues(alpha: leftOpacities[i]);
      canvas.drawLine(
        Offset(lineStartX + curveOffset, y),
        Offset(lineEndX, y),
        textLinePaint,
      );
    }

    // Lignes de texte simulées — page droite
    final rLineStartX = center.dx + bookSize * 0.1;
    final rLineEndX = center.dx + bookSize * 0.5;

    const rightOpacities = [0.3, 0.25, 0.2, 0.15];
    for (int i = 0; i < 4; i++) {
      final y = firstLineY + i * lineSpacing;
      final progress = i / 3.0;
      final curveOffset = bookSize * 0.08 * progress;
      textLinePaint.color = primary.withValues(alpha: rightOpacities[i]);
      canvas.drawLine(
        Offset(rLineStartX, y),
        Offset(rLineEndX - curveOffset, y),
        textLinePaint,
      );
    }

    // Checkmark ✓ en haut à droite de la page droite
    final checkX = center.dx + bookSize * 0.38;
    final checkY = bookTop + bookSize * 0.2;
    final checkPath = Path()
      ..moveTo(checkX - bookSize * 0.08, checkY)
      ..lineTo(checkX - bookSize * 0.02, checkY + bookSize * 0.08)
      ..lineTo(checkX + bookSize * 0.08, checkY - bookSize * 0.06);

    canvas.drawPath(
      checkPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawLabels(Canvas canvas, Offset center, Size size) {
    // "1er" en haut
    final topPainter = TextPainter(
      text: TextSpan(
        text: '1er',
        style: TextStyle(
          fontSize: size.width * 0.09,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.75),
          letterSpacing: 2,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    topPainter.layout();
    topPainter.paint(
      canvas,
      Offset(
        center.dx - topPainter.width / 2,
        center.dy - size.width * 0.32,
      ),
    );

    // "LIVRE" en bas
    final bottomPainter = TextPainter(
      text: TextSpan(
        text: 'LIVRE',
        style: TextStyle(
          fontSize: size.width * 0.09,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.8),
          letterSpacing: 3,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    bottomPainter.layout();
    bottomPainter.paint(
      canvas,
      Offset(
        center.dx - bottomPainter.width / 2,
        center.dy + size.width * 0.24,
      ),
    );
  }

  void _drawDecorativeDots(Canvas canvas, Offset center, double radius) {
    final dotRadius = radius * 0.65;
    final dotSize = 2.0;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    // 4 points à 0°, 90°, 180°, 270°
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) - math.pi / 2;
      final x = center.dx + dotRadius * math.cos(angle);
      final y = center.dy + dotRadius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FirstBookBadgePainter oldDelegate) => false;
}

/// Vérifie si un badge est le badge "Premier Livre" (1er livre terminé).
/// Fonctionne quel que soit l'ID en base (books_1, first_book, etc.)
/// Accepte des champs optionnels pour matcher sur category/requirement quand dispo.
bool isFirstBookBadge({required String id, String? category, int? requirement}) {
  if (id == 'books_1' || id == 'first_book') return true;
  if (category == 'books_completed' && requirement == 1) return true;
  return false;
}

/// Widget réutilisable pour afficher le badge Premier Livre.
/// S'utilise partout où le badge books_1 doit être affiché avec son rendu custom.
class FirstBookBadgeWidget extends StatelessWidget {
  final double size;
  final bool isLocked;

  const FirstBookBadgeWidget({
    super.key,
    this.size = 80,
    this.isLocked = false,
  });

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget badge = SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: FirstBookBadgePainter(),
      ),
    );

    if (isLocked) {
      badge = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(
          opacity: 0.45,
          child: badge,
        ),
      );
    }

    return badge;
  }
}

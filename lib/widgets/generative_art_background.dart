import 'dart:math' as math;

import 'package:flutter/material.dart';

class GenerativeArtBackground extends StatelessWidget {
  const GenerativeArtBackground({
    super.key,
    required this.seed,
    this.opacity = 1,
  });

  final int seed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: RepaintBoundary(
        child: CustomPaint(painter: _ArtPainter(seed), size: Size.infinite),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.seed);

  final int seed;

  static const _palette = [
    Color(0xFF6EC7C4),
    Color(0xFFFFB59D),
    Color(0xFFFFD98E),
    Color(0xFF91B8E5),
    Color(0xFFB8A7E8),
    Color(0xFF9ED8B3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(seed);

    for (var i = 0; i < 15; i++) {
      final center = _point(random, size);
      final radius = 18.0 + random.nextDouble() * 78;
      final filled = random.nextBool();
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _color(random, filled ? 0.13 : 0.23)
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.2 + random.nextDouble() * 2,
      );
    }

    for (var i = 0; i < 10; i++) {
      final center = _point(random, size);
      final radius = 25.0 + random.nextDouble() * 72;
      final rotation = random.nextDouble() * math.pi * 2;
      final path = Path();
      for (var side = 0; side < 3; side++) {
        final angle = rotation + (math.pi * 2 * side / 3);
        final point = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );
        side == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      path.close();
      final filled = random.nextDouble() > 0.55;
      canvas.drawPath(
        path,
        Paint()
          ..color = _color(random, filled ? 0.10 : 0.22)
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.3 + random.nextDouble() * 2,
      );
    }

    for (var i = 0; i < 13; i++) {
      final start = _point(random, size);
      final end = _point(random, size);
      final bend = 35.0 + random.nextDouble() * 130;
      final path = Path()..moveTo(start.dx, start.dy);

      if (random.nextBool()) {
        path.quadraticBezierTo(
          (start.dx + end.dx) / 2 + (random.nextDouble() - 0.5) * bend,
          (start.dy + end.dy) / 2 + (random.nextDouble() - 0.5) * bend,
          end.dx,
          end.dy,
        );
      } else {
        path.cubicTo(
          start.dx + (random.nextDouble() - 0.5) * bend,
          start.dy + (random.nextDouble() - 0.5) * bend,
          end.dx + (random.nextDouble() - 0.5) * bend,
          end.dy + (random.nextDouble() - 0.5) * bend,
          end.dx,
          end.dy,
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = _color(random, 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + random.nextDouble() * 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  Offset _point(math.Random random, Size size) {
    return Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
  }

  Color _color(math.Random random, double alpha) {
    return _palette[random.nextInt(_palette.length)].withValues(alpha: alpha);
  }

  @override
  bool shouldRepaint(covariant _ArtPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

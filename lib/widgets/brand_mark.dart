import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A marca do MenuWatch: um prato visto de cima com um ponto de aviso.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    required this.ring,
    required this.dot,
    required this.background,
    this.ringProgress = 1,
    this.dotScale = 1,
  });

  final double size;
  final Color ring;
  final Color dot;

  /// Cor atrás da marca, usada para recortar o anel em volta do ponto.
  final Color background;

  /// 0 a 1: quanto do anel já foi desenhado.
  final double ringProgress;
  final double dotScale;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MarkPainter(ring, dot, background, ringProgress, dotScale),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.ring, this.dot, this.background, this.progress, this.scale);

  final Color ring;
  final Color dot;
  final Color background;
  final double progress;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // Mesmas proporções do ícone do app (anel de raio 22 em um quadro de 64).
    final u = size.width / 64;
    final center = Offset(30 * u, 34 * u);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 22 * u),
      -math.pi / 4,
      2 * math.pi * progress,
      false,
      stroke
        ..color = ring
        ..strokeWidth = 6.5 * u,
    );
    if (progress >= 1) {
      canvas.drawCircle(
        center,
        10.5 * u,
        stroke
          ..color = ring.withValues(alpha: 0.32)
          ..strokeWidth = 2.2 * u,
      );
    }
    if (scale > 0) {
      final at = Offset(47 * u, 17 * u);
      canvas.drawCircle(at, 12.5 * u * scale, Paint()..color = background);
      canvas.drawCircle(at, 8.5 * u * scale, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.ring != ring ||
      old.dot != dot ||
      old.background != background ||
      old.progress != progress ||
      old.scale != scale;
}

/// Prato vazio desenhado em traço, para as telas sem conteúdo.
class EmptyPlate extends StatelessWidget {
  const EmptyPlate({super.key, this.size = 132, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _PlatePainter(color),
  );
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(c, r * 0.96, Paint()..color = color.withValues(alpha: 0.07));
    canvas.drawCircle(c, r * 0.72, line..strokeWidth = r * 0.045);
    canvas.drawCircle(
      c,
      r * 0.46,
      line
        ..strokeWidth = r * 0.028
        ..color = color.withValues(alpha: 0.45),
    );
    // Reflexo na borda do prato.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.59),
      -math.pi * 0.95,
      math.pi * 0.28,
      false,
      line
        ..strokeWidth = r * 0.03
        ..color = color.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.color != color;
}

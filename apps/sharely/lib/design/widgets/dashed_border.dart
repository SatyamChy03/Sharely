import 'package:flutter/material.dart';

/// Paints a dashed rounded border, which Flutter's [Border] can't draw.
class DashedBorder extends StatelessWidget {
  const new({
    required this.color,
    required this.radius,
    required this.child,
    super.key,
    this.strokeWidth = 2,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(color, radius, strokeWidth),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const new(this.color, this.radius, this.strokeWidth);

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dash = 8.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        canvas.drawPath(metric.extractPath(start, start + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

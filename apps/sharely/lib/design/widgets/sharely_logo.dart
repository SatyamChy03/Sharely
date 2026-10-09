import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// The Sharely mark: an S-shaped path from a start dot to a destination dot.
class SharelyLogoMark extends StatelessWidget {
  const new({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sharely',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _LogoMarkPainter(),
      ),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    // Geometry is authored on a 64-unit grid to match the brand board.
    final scale = size.width / 64;
    canvas.scale(scale);
    final curve = Path()
      ..moveTo(16, 18)
      ..cubicTo(54, 18, 10, 46, 48, 46);
    final stroke = Paint()
      ..color = SharelyColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(curve, stroke)
      ..drawCircle(const Offset(16, 18), 7, Paint()..color = SharelyColors.text)
      ..drawCircle(
        const Offset(48, 46),
        7,
        Paint()..color = SharelyColors.primary,
      );
  }

  @override
  bool shouldRepaint(_LogoMarkPainter oldDelegate) => false;
}

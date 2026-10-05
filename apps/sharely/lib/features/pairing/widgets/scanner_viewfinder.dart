import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sharely/design/tokens.dart';

/// Dark rounded camera frame with corner guides and a sweeping scan line.
class ScannerViewfinder extends StatelessWidget {
  const new({required this.camera, super.key, this.isScanning = true});

  final Widget camera;
  final bool isScanning;

  static const _guideSize = 224.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(SharelyRadii.panel),
      child: ColoredBox(
        color: SharelyColors.ink,
        child: Stack(
          fit: StackFit.expand,
          children: [
            camera,
            Center(
              child: SizedBox.square(
                dimension: _guideSize,
                child: Stack(
                  children: [
                    for (final alignment in _corners)
                      Align(alignment: alignment, child: _Corner(alignment)),
                    if (isScanning) const _ScanLine(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Alignment> _corners = [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomLeft,
    Alignment.bottomRight,
  ];
}

class _Corner extends StatelessWidget {
  const new(this.alignment);

  final Alignment alignment;

  // The painter draws a top-left corner; rotate it into place for the others.
  int get _quarterTurns => switch (alignment) {
    Alignment.topRight => 1,
    Alignment.bottomRight => 2,
    Alignment.bottomLeft => 3,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: _quarterTurns,
      child: const CustomPaint(
        size: Size.square(48),
        painter: _CornerPainter(),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    const inset = strokeWidth / 2;
    const radius = 18.0;
    final path = Path()
      ..moveTo(inset, size.height)
      ..lineTo(inset, radius)
      ..arcToPoint(
        const Offset(radius, inset),
        radius: const Radius.circular(radius - inset),
      )
      ..lineTo(size.width, inset);
    canvas.drawPath(
      path,
      Paint()
        ..color = SharelyColors.accentOnInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => false;
}

class _ScanLine extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: SharelyColors.accentOnInk,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: line
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(
            begin: 24,
            end: 196,
            duration: 1600.ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}

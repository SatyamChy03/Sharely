import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// The big ring on the sending screen: percent in the middle, speed below.
class SendProgressRing extends StatelessWidget {
  const new({
    required this.fraction,
    required this.headline,
    required this.caption,
    super.key,
  });

  final double fraction;
  final String headline;
  final String caption;

  static const _size = 240.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0, 1)),
        duration: SharelyMotion.medium,
        curve: SharelyMotion.standard,
        builder: (context, value, child) =>
            CustomPaint(painter: _RingPainter(value), child: child),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 2,
          children: [
            Text(
              headline,
              style: sharelyMonoStyle(
                size: 54,
                color: SharelyColors.surface,
              ).copyWith(letterSpacing: -2),
            ),
            Text(
              caption,
              style: sharelyMonoStyle(
                size: 14,
                color: SharelyColors.accentOnInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new(this.fraction);

  final double fraction;

  static const _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(_strokeWidth / 2 + 2);
    final track = Paint()
      ..color = SharelyColors.inkBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    if (fraction <= 0) return;
    final progress = Paint()
      ..color = SharelyColors.accentOnInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi * fraction, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

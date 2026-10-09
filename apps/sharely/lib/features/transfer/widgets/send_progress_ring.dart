import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// The big ring on the sending screen: percent in the middle, bytes below.
class SendProgressRing extends StatelessWidget {
  const new({
    required this.fraction,
    required this.caption,
    super.key,
    this.isStalled = false,
  });

  final double fraction;
  final String caption;

  /// Greys the arc while the transfer waits for the connection to return.
  final bool isStalled;

  static const _size = 208.0;

  @override
  Widget build(BuildContext context) {
    final percent = (fraction.clamp(0, 1) * 100).floor();
    return Semantics(
      label: 'Overall transfer progress',
      value: '$percent percent',
      child: SizedBox.square(
        dimension: _size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction.clamp(0, 1)),
          duration: SharelyMotion.medium,
          curve: SharelyMotion.standard,
          builder: (context, value, child) => CustomPaint(
            painter: _RingPainter(value, isStalled: isStalled),
            child: child,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              _Percent(percent),
              Text(
                caption,
                style: sharelyMonoStyle(
                  size: 13,
                  color: SharelyColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Percent extends StatelessWidget {
  const new(this.percent);

  final int percent;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge?.copyWith(
      fontSize: 52,
      letterSpacing: -2,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          text: '$percent',
          children: const [
            TextSpan(
              text: '%',
              style: TextStyle(
                fontSize: 26,
                letterSpacing: 0,
                color: SharelyColors.textSecondary,
              ),
            ),
          ],
        ),
        style: style,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new(this.fraction, {required this.isStalled});

  final double fraction;
  final bool isStalled;

  static const _strokeWidth = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(_strokeWidth / 2 + 2);
    final track = Paint()
      ..color = SharelyColors.elevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    if (fraction <= 0) return;
    final progress = Paint()
      ..color = isStalled ? SharelyColors.stalled : SharelyColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi * fraction, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.isStalled != isStalled;
}

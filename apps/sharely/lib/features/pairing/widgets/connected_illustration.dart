import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Phone and laptop joined by a solid S-path, with a check popping in.
/// Authored on a 350x240 canvas and scaled to fit.
class ConnectedIllustration extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(SharelyRadii.panel),
        child: ColoredBox(
          color: SharelyColors.ink,
          child: FittedBox(
            child: SizedBox(
              width: 350,
              height: 240,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                      duration: SharelyMotion.slow,
                      curve: SharelyMotion.emphasized,
                      builder: (context, progress, _) => CustomPaint(
                        painter: _ConnectionPathPainter(progress),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 36,
                    top: 120,
                    child: _Tile(LucideIcons.smartphone, SharelyColors.surface),
                  ),
                  const Positioned(
                    left: 244,
                    top: 44,
                    child: _Tile(LucideIcons.laptop, SharelyColors.accent),
                  ),
                  Positioned(left: 151, top: 96, child: _checkBadge()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkBadge() {
    return Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: SharelyColors.surface,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.check, color: SharelyColors.ink),
        )
        .animate(delay: SharelyMotion.medium)
        .scaleXY(
          begin: 0,
          duration: SharelyMotion.slow,
          curve: Curves.elasticOut,
        );
  }
}

class _Tile extends StatelessWidget {
  const new(this.icon, this.background);

  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final foreground = background == SharelyColors.accent
        ? SharelyColors.onAccent
        : SharelyColors.ink;
    return Container(
      width: 72,
      height: 76,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(SharelyRadii.tile),
      ),
      child: Icon(icon, size: 28, color: foreground),
    );
  }
}

class _ConnectionPathPainter extends CustomPainter {
  const new(this.progress);

  final double progress;

  static final PathMetric _metric =
      (Path()
            ..moveTo(92, 160)
            ..cubicTo(180, 160, 170, 80, 258, 80))
          .computeMetrics()
          .first;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SharelyColors.accentOnInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_metric.extractPath(0, _metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_ConnectionPathPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

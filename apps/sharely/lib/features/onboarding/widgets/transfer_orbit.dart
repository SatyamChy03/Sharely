import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// Welcome illustration: a file travels from phone to laptop on the S-path.
/// Authored on a 342x300 canvas and scaled to fit.
class TransferOrbit extends StatefulWidget {
  const new({super.key});

  @override
  State<TransferOrbit> createState() => _TransferOrbitState();
}

class _TransferOrbitState extends State<TransferOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: SharelyMotion.transferLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _travel.value = 1;
    } else if (!_travel.isAnimating) {
      _travel.repeat();
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FittedBox(
        child: SizedBox(
          width: 342,
          height: 300,
          child: Stack(
            children: [
              const _OrbitRing(left: 21, top: 0, diameter: 300),
              const _OrbitRing(left: 71, top: 50, diameter: 200),
              const _OrbitRing(left: 121, top: 100, diameter: 100),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _TransferPathPainter(_travel)),
                ),
              ),
              const _DeviceTiles(),
              const Positioned(left: 112, top: 132, child: _FloatingFileChip()),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitRing extends StatelessWidget {
  const new({required this.left, required this.top, required this.diameter});

  final double left;
  final double top;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SharelyColors.inkBorder),
        ),
      ),
    );
  }
}

class _DeviceTiles extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    const phone = _DeviceTile(
      icon: LucideIcons.smartphone,
      width: 72,
      height: 80,
      background: SharelyColors.surface,
      foreground: SharelyColors.ink,
    );
    const laptop = _DeviceTile(
      icon: LucideIcons.laptop,
      width: 80,
      height: 80,
      background: SharelyColors.accent,
      foreground: SharelyColors.onAccent,
    );
    return Stack(
      children: [
        Positioned(left: 30, top: 184, child: _popIn(phone, Duration.zero)),
        Positioned(left: 236, top: 36, child: _popIn(laptop, 120.ms)),
      ],
    );
  }

  Widget _popIn(Widget tile, Duration delay) {
    return tile
        .animate(delay: delay)
        .fadeIn(duration: SharelyMotion.slow)
        .scaleXY(begin: 0.85, curve: SharelyMotion.emphasized);
  }
}

class _DeviceTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.width,
    required this.height,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final double width;
  final double height;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(SharelyRadii.tile),
      ),
      child: Icon(icon, size: 30, color: foreground),
    );
  }
}

class _FloatingFileChip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final nameStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontSize: 13, color: SharelyColors.surface);
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: SharelyColors.inkRaised,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: SharelyColors.inkBorderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              const Icon(
                LucideIcons.image,
                size: 20,
                color: SharelyColors.accentOnInk,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IMG_2041.jpg', style: nameStyle),
                  Text(
                    '4.2 MB · 0.3 s',
                    style: sharelyMonoStyle(
                      size: 11,
                      color: SharelyColors.onInkMuted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: -4, end: 4, duration: 1800.ms, curve: Curves.easeInOut);
  }
}

class _TransferPathPainter extends CustomPainter {
  new(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static final Color _glowColor = SharelyColors.accentOnInk.withValues(
    alpha: 0.25,
  );

  static final Path _curve = Path()
    ..moveTo(70, 224)
    ..cubicTo(200, 224, 140, 76, 272, 76);

  @override
  void paint(Canvas canvas, Size size) {
    final metric = _curve.computeMetrics().first;
    _paintDashes(canvas, metric);
    final position = metric
        .getTangentForOffset(metric.length * progress.value)
        ?.position;
    if (position == null) return;
    final dotPaint = Paint()..color = SharelyColors.accentOnInk;
    canvas
      ..drawCircle(position, 12, dotPaint..color = _glowColor)
      ..drawCircle(position, 6, dotPaint..color = SharelyColors.accentOnInk);
  }

  void _paintDashes(Canvas canvas, PathMetric metric) {
    const dashLength = 2.0;
    const gapLength = 10.0;
    final dashPaint = Paint()
      ..color = SharelyColors.accentOnInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var d = 0.0; d < metric.length; d += dashLength + gapLength) {
      canvas.drawPath(metric.extractPath(d, d + dashLength), dashPaint);
    }
  }

  @override
  bool shouldRepaint(_TransferPathPainter oldDelegate) => false;
}

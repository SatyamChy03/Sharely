import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// Rings that expand and fade around [child] while something is awaited.
class PulseRings extends StatefulWidget {
  const new({
    required this.child,
    required this.size,
    super.key,
    this.radius = SharelyRadii.zone,
  });

  final Widget child;
  final double size;
  final Radius radius;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SharelyMotion.transferLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(child: _ring(0)),
          RepaintBoundary(child: _ring(0.5)),
          widget.child,
        ],
      ),
    );
  }

  Widget _ring(double offset) {
    final ring = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(widget.radius),
        border: Border.all(color: SharelyColors.primary, width: 1.5),
      ),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: ring,
      builder: (context, child) {
        final progress = SharelyMotion.standard.transform(
          (_controller.value + offset) % 1,
        );
        return Opacity(
          opacity: 0.55 * (1 - progress),
          child: Transform.scale(scale: 0.9 + progress * 0.6, child: child),
        );
      },
    );
  }
}

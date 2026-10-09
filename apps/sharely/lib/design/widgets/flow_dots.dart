import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// Dots that light up in turn, showing data moving between two devices.
class FlowDots extends StatefulWidget {
  const new({super.key, this.count = 4, this.dotSize = 6});

  final int count;
  final double dotSize;

  @override
  State<FlowDots> createState() => _FlowDotsState();
}

class _FlowDotsState extends State<FlowDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: widget.dotSize + 2,
        children: [
          for (var index = 0; index < widget.count; index++) _dot(index),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    final dot = Container(
      width: widget.dotSize,
      height: widget.dotSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SharelyColors.primary,
      ),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: dot,
      builder: (context, child) {
        final phase = (_controller.value - index * 0.125) % 1;
        final distance = (phase - 0.5).abs() * 2;
        return Opacity(opacity: 1 - distance * 0.78, child: child);
      },
    );
  }
}

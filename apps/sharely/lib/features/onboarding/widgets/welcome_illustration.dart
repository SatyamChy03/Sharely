import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/dashed_border.dart';
import 'package:sharely/design/widgets/file_kind.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/flow_dots.dart';

/// A laptop and a phone with a file moving between them.
class WelcomeIllustration extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Ring(diameter: 280),
            _Ring(diameter: 190),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 22,
              children: [_LaptopOutline(), _PhoneOutline()],
            ),
            Positioned(left: 148, top: 124, child: FlowDots(count: 3)),
            Positioned(left: 20, top: 52, child: _SentFileChip()),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const new({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SharelyColors.line),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SharelyColors.lineStrong,
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
      ),
    );
  }
}

class _LaptopOutline extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final screen = Container(
      width: 148,
      height: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: const BorderRadius.all(SharelyRadii.button),
        border: Border.all(color: SharelyColors.lineHover, width: 1.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          _Bar(width: 52, height: 8),
          Expanded(
            child: DashedBorder(
              color: SharelyColors.primary,
              radius: 6,
              strokeWidth: 1.5,
              child: Center(
                child: Icon(
                  LucideIcons.arrowDown,
                  size: 18,
                  color: SharelyColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        screen,
        Container(
          width: 176,
          height: 8,
          decoration: const BoxDecoration(
            color: SharelyColors.lineHover,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
          ),
        ),
      ],
    );
  }
}

class _PhoneOutline extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: const BorderRadius.all(SharelyRadii.tile),
        border: Border.all(color: SharelyColors.lineHover, width: 1.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          FileThumb(kind: FileKind.image, size: 30),
          FileThumb(kind: FileKind.image, size: 30, tone: 1),
          _Bar(width: 24, height: 5),
        ],
      ),
    );
  }
}

class _SentFileChip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SharelyColors.elevated,
        borderRadius: const BorderRadius.all(SharelyRadii.row),
        border: Border.all(color: SharelyColors.lineStrong),
        boxShadow: const [
          BoxShadow(
            color: SharelyColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: SharelySpacing.sm,
        children: [
          const FileThumb(
            kind: FileKind.image,
            size: 16,
            radius: Radius.circular(4),
          ),
          Text('IMG_2051.jpg', style: Theme.of(context).textTheme.labelSmall),
          const Icon(LucideIcons.check, size: 14, color: SharelyColors.success),
        ],
      ),
    );
  }
}

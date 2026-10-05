import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// Dark card at the top of the phone home: the laptop, its link, and Send.
class DeviceHeroCard extends StatelessWidget {
  const new({
    required this.laptopName,
    required this.status,
    required this.isConnected,
    required this.sendLabel,
    required this.onSend,
    super.key,
    this.fixLabel,
    this.onFix,
  });

  final String laptopName;
  final String status;
  final bool isConnected;
  final String sendLabel;
  final VoidCallback? onSend;

  /// One suggested fix when the laptop can't be reached, e.g. "Retry".
  final String? fixLabel;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final label = fixLabel;
    return ClipRRect(
      borderRadius: const BorderRadius.all(SharelyRadii.card),
      child: ColoredBox(
        color: SharelyColors.ink,
        child: Stack(
          children: [
            const Positioned(right: -60, top: -60, child: _Ring(size: 200)),
            const Positioned(
              right: -20,
              top: -20,
              child: _Ring(size: 120, color: SharelyColors.inkBorderStrong),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 18,
                children: [
                  _LaptopRow(
                    laptopName: laptopName,
                    status: status,
                    isConnected: isConnected,
                  ),
                  if (label != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: onFix, child: Text(label)),
                    ),
                  SharelyButton(
                    label: sendLabel,
                    leadingIcon: LucideIcons.arrowUp,
                    onPressed: onSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const new({required this.size, this.color = SharelyColors.inkBorder});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
    );
  }
}

class _LaptopRow extends StatelessWidget {
  const new({
    required this.laptopName,
    required this.status,
    required this.isConnected,
  });

  final String laptopName;
  final String status;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      spacing: SharelySpacing.md,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: SharelyColors.inkRaisedHigh,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: const Icon(
            LucideIcons.laptop,
            color: SharelyColors.accentOnInk,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(
                laptopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: SharelyColors.surface,
                  fontSize: 18,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: _StatusDot(isConnected: isConnected),
                  ),
                  Flexible(
                    child: Text(
                      status,
                      style: textTheme.bodySmall?.copyWith(
                        color: SharelyColors.onInkQuiet,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const new({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: isConnected ? SharelyColors.accent : SharelyColors.onInkMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// Dark card at the top of the phone home: the laptop, its link, and Send.
class DeviceHeroCard extends StatelessWidget {
  const new({
    required this.laptopName,
    required this.status,
    required this.isConnected,
    required this.onSend,
    super.key,
    this.fixLabel,
    this.onFix,
  });

  final String laptopName;
  final String status;
  final bool isConnected;
  final VoidCallback? onSend;

  /// One suggested fix when the laptop can't be reached, e.g. "Retry".
  final String? fixLabel;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final label = fixLabel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: SharelyColors.ink,
        borderRadius: BorderRadius.all(SharelyRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const Gap(18),
          SharelyButton(
            label: 'Send to laptop',
            trailingIcon: LucideIcons.arrowUp,
            onPressed: onSend,
          ),
        ],
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
            children: [
              Text(
                laptopName,
                style: textTheme.titleMedium?.copyWith(
                  color: SharelyColors.surface,
                ),
              ),
              Row(
                spacing: 6,
                children: [
                  _StatusDot(isConnected: isConnected),
                  Flexible(
                    child: Text(
                      status,
                      style: textTheme.bodySmall?.copyWith(
                        color: SharelyColors.onInkSoft,
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
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isConnected
            ? SharelyColors.accentOnInk
            : SharelyColors.onInkMuted.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

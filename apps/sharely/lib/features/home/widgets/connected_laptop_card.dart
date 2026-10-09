import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';

/// The laptop this phone talks to: its name, the link's state and one action.
class ConnectedLaptopCard extends StatelessWidget {
  const new({
    required this.laptopName,
    required this.statusLabel,
    required this.tone,
    required this.actionLabel,
    required this.onAction,
    super.key,
    this.detail,
    this.isActionPrimary = false,
  });

  final String laptopName;
  final String statusLabel;
  final StatusTone tone;

  /// "Change" while connected; the one suggested fix otherwise.
  final String actionLabel;
  final VoidCallback? onAction;

  /// True when the action is the fix for a link that is down.
  final bool isActionPrimary;

  /// What to do about a link that is down, in a sentence.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final help = detail;
    final isConnected = tone == StatusTone.connected;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.md,
        children: [
          Row(
            spacing: 14,
            children: [
              IconTile(
                icon: LucideIcons.laptop,
                size: 48,
                radius: SharelyRadii.tile,
                color: isConnected
                    ? SharelyColors.primary
                    : SharelyColors.textSecondary,
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
                      style: textTheme.titleMedium,
                    ),
                    StatusBadge(label: statusLabel, tone: tone, isPlain: true),
                  ],
                ),
              ),
              SharelyButton(
                label: actionLabel,
                variant: isActionPrimary
                    ? SharelyButtonVariant.primary
                    : SharelyButtonVariant.secondary,
                height: SharelySizes.buttonMedium,
                isExpanded: false,
                onPressed: onAction,
              ),
            ],
          ),
          if (help != null)
            Text(
              help,
              style: textTheme.bodySmall?.copyWith(
                color: SharelyColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

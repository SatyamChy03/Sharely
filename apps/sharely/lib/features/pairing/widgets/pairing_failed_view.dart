import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_square_button.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/pairing_issue_text.dart';

/// Pairing did not work (M15): what happened and the one thing to try.
class PairingFailedView extends StatelessWidget {
  const new({required this.issue, required this.onTryAgain, super.key});

  final PhonePairingIssue issue;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final text = describePairingIssue(issue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconSquareButton(
          icon: LucideIcons.chevronLeft,
          tooltip: 'Back',
          onPressed: onTryAgain,
        ),
        const Gap(SharelySpacing.xl),
        const IconTile(
          icon: LucideIcons.wifiOff,
          size: 64,
          radius: SharelyRadii.zone,
          color: SharelyColors.dangerText,
          background: SharelyColors.dangerTint,
          borderColor: SharelyColors.dangerLine,
        ),
        const Gap(SharelySpacing.lg),
        const StatusBadge(label: 'Connection failed', tone: StatusTone.failed),
        const Gap(SharelySpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(text.title, style: textTheme.headlineLarge),
        ),
        const Gap(SharelySpacing.sm),
        Text(
          'Nothing was sent.',
          style: textTheme.bodyMedium?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
        const Gap(SharelySpacing.xl),
        SurfaceCard(
          radius: SharelyRadii.zone,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: SharelySpacing.md,
            children: [
              const IconTile(
                icon: LucideIcons.lightbulb,
                size: 32,
                radius: SharelyRadii.row,
                color: SharelyColors.text,
              ),
              Expanded(child: Text(text.fix, style: textTheme.bodyMedium)),
            ],
          ),
        ),
        const Spacer(),
        SharelyButton(
          label: 'Try again',
          leadingIcon: LucideIcons.refreshCw,
          onPressed: onTryAgain,
        ),
      ],
    );
  }
}

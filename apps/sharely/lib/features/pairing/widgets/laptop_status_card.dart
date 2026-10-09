import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// Laptop pairing when there is no code to show: offline, error, loading.
class LaptopStatusCard extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    super.key,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final IconData? icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = actionLabel;
    final statusIcon = icon;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusIcon == null)
            const SizedBox.square(
              dimension: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: SharelyColors.primary,
                backgroundColor: SharelyColors.lineStrong,
              ),
            )
          else
            IconTile(
              icon: statusIcon,
              size: 72,
              radius: SharelyRadii.zone,
              color: SharelyColors.dangerText,
              background: SharelyColors.dangerTint,
              borderColor: SharelyColors.dangerLine,
            ),
          const Gap(SharelySpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineLarge,
          ),
          const Gap(SharelySpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: SharelyColors.textSecondary,
            ),
          ),
          if (label != null) ...[
            const Gap(SharelySpacing.xl),
            SharelyButton(
              label: label,
              leadingIcon: LucideIcons.refreshCw,
              height: SharelySizes.buttonMedium,
              isExpanded: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  static const IconData offlineIcon = LucideIcons.wifiOff;
  static const IconData errorIcon = LucideIcons.circleAlert;
}

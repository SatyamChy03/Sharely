import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// White card for the laptop's non-QR states: paired, offline, loading.
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
    return Container(
      padding: const EdgeInsets.all(SharelySpacing.xxl),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(SharelyRadii.panel),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusIcon == null)
            const CircularProgressIndicator(color: SharelyColors.accent)
          else
            CircleAvatar(
              radius: 28,
              backgroundColor: SharelyColors.ink,
              child: Icon(statusIcon, color: SharelyColors.accentOnInk),
            ),
          const Gap(SharelySpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(color: SharelyColors.ink),
          ),
          const Gap(SharelySpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
          ),
          if (label != null) ...[
            const Gap(SharelySpacing.xl),
            SharelyButton(
              label: label,
              variant: SharelyButtonVariant.ink,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  static const IconData pairedIcon = LucideIcons.check;
  static const IconData offlineIcon = LucideIcons.wifiOff;
  static const IconData errorIcon = LucideIcons.circleAlert;
}

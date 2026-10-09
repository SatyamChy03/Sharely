import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';

/// The surface panel of the laptop welcome: the promise and three reasons.
class LaptopWelcomePitch extends StatelessWidget {
  const new({required this.isFillingHeight, super.key});

  /// Side by side the panel fills the window; stacked it wraps its content.
  final bool isFillingHeight;

  @override
  Widget build(BuildContext context) {
    final isCompact = !isFillingHeight;
    const message = _Message();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SharelyColors.surface,
        border: Border(
          right: isCompact
              ? BorderSide.none
              : const BorderSide(color: SharelyColors.line),
          bottom: isCompact
              ? const BorderSide(color: SharelyColors.line)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? SharelySpacing.xxl : 56,
          vertical: isCompact ? SharelySpacing.xxl : SharelySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
          spacing: 40,
          children: [
            const SharelyWordmark(markSize: 30),
            if (isCompact)
              message
            else
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(child: message),
                ),
              ),
            Text(
              platformDisplayName(currentDevicePlatform),
              style: sharelyMonoStyle(
                size: 12,
                color: SharelyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 22,
        children: [
          Text.rich(
            const TextSpan(
              text: 'Transfer anything between your devices. ',
              children: [
                TextSpan(
                  text: 'Instantly.',
                  style: TextStyle(color: SharelyColors.primary),
                ),
              ],
            ),
            style: textTheme.displayLarge?.copyWith(height: 1.04),
          ),
          Text(
            'Drag a file onto Sharely and it lands on your phone. Send '
            'from your phone and it lands here.',
            style: textTheme.titleMedium?.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: SharelyColors.textSecondary,
            ),
          ),
          const _Reasons(),
        ],
      ),
    );
  }
}

class _Reasons extends StatelessWidget {
  const new();

  static const List<({IconData icon, String title, String body})> _reasons = [
    (
      icon: LucideIcons.arrowUp,
      title: 'Drag, drop, done.',
      body: 'No cables, no cloud uploads.',
    ),
    (
      icon: LucideIcons.shieldCheck,
      title: 'Direct and private.',
      body: 'Files move between your own devices.',
    ),
    (
      icon: LucideIcons.arrowUpDown,
      title: 'Both ways.',
      body: 'Phone to laptop and back again.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(top: SharelySpacing.sm),
      child: Column(
        spacing: 14,
        children: [
          for (final reason in _reasons)
            Row(
              spacing: 14,
              children: [
                IconTile(icon: reason.icon, size: 36),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '${reason.title} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      children: [
                        TextSpan(
                          text: reason.body,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            color: SharelyColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    style: bodyStyle,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

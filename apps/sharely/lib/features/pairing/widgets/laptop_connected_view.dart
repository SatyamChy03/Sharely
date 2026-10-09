import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/result_mark.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely_core/sharely_core.dart';

/// Pairing finished on the laptop (D04): the phone is ready to use.
class LaptopConnectedView extends StatelessWidget {
  const new({
    required this.phone,
    required this.onStartSending,
    required this.onPairAnother,
    super.key,
  });

  final PairedDevice phone;
  final VoidCallback onStartSending;
  final VoidCallback onPairAnother;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(child: ResultMark()),
          const Gap(28),
          const StatusBadge(label: 'Paired', tone: StatusTone.connected),
          const Gap(SharelySpacing.md),
          Text(
            '${phone.deviceName} is ready',
            textAlign: TextAlign.center,
            style: textTheme.displayMedium,
          ),
          const Gap(SharelySpacing.md),
          Text(
            'Wi-Fi  ·  Direct, device to device  ·  '
            '${platformDisplayName(phone.platform)}',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: SharelyColors.textSecondary,
            ),
          ),
          const Gap(28),
          const _TipCards(),
          const Gap(28),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        SharelyButton(
          label: 'Start sending',
          trailingIcon: LucideIcons.arrowRight,
          height: 48,
          isExpanded: false,
          onPressed: onStartSending,
        ),
        SharelyButton(
          label: 'Pair another device',
          variant: SharelyButtonVariant.secondary,
          height: 48,
          isExpanded: false,
          onPressed: onPairAnother,
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const new({required this.icon, required this.lead, required this.rest});

  final IconData icon;
  final String lead;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: SharelyRadii.zone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SharelySpacing.md,
        children: [
          Icon(icon, size: 20, color: SharelyColors.primary),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: lead,
                style: const TextStyle(color: SharelyColors.text),
                children: [TextSpan(text: rest)],
              ),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color: SharelyColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCards extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.md,
        children: [
          Expanded(
            child: _TipCard(
              icon: LucideIcons.arrowUp,
              lead: 'To send,',
              rest: ' drop files anywhere on Home.',
            ),
          ),
          Expanded(
            child: _TipCard(
              icon: LucideIcons.arrowDown,
              lead: 'To receive,',
              rest: ' just send from your phone.',
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/result_mark.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';

/// Pairing finished (M05): the phone now trusts the laptop.
class ConnectedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final laptopName = devices.isEmpty
        ? 'Your laptop'
        : devices.last.deviceName;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              const ExcludeSemantics(child: ResultMark(size: 128)),
              const Gap(28),
              const StatusBadge(label: 'Connected', tone: StatusTone.connected),
              const Gap(SharelySpacing.md),
              Text(
                laptopName,
                textAlign: TextAlign.center,
                style: textTheme.displaySmall,
              ),
              const Gap(SharelySpacing.md),
              const _ConnectionFacts(),
              const Gap(SharelySpacing.xxl),
              const _PairedForNextTimeCard(),
              const Spacer(),
              SharelyButton(
                label: 'Start sending',
                trailingIcon: LucideIcons.arrowRight,
                onPressed: () => context.go(AppRoutes.home),
              ),
              const Gap(10),
              SharelyButton(
                label: 'Pair another device',
                variant: SharelyButtonVariant.ghost,
                height: SharelySizes.buttonMedium,
                onPressed: () => context.go(AppRoutes.scan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionFacts extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w400,
      color: SharelyColors.textSecondary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 6,
      children: [
        const Icon(LucideIcons.wifi, size: 15, color: SharelyColors.primary),
        Text('Wi-Fi', style: style),
        Text('·', style: style),
        Text('Direct, device to device', style: style),
      ],
    );
  }
}

class _PairedForNextTimeCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: SharelyColors.textSecondary,
    );
    return SurfaceCard(
      radius: SharelyRadii.zone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SharelySpacing.md,
        children: [
          const Icon(
            LucideIcons.refreshCw,
            size: 20,
            color: SharelyColors.primary,
          ),
          Expanded(
            child: Text.rich(
              const TextSpan(
                text: 'Paired for next time. ',
                style: TextStyle(
                  color: SharelyColors.text,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text:
                        'Your devices reconnect on their own whenever '
                        'they share a network.',
                    style: TextStyle(
                      color: SharelyColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

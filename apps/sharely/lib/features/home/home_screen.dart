import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/home/widgets/device_hero_card.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';

/// Phone home. Sending is wired up in the transfer step.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: SharelyWordmark(markSize: 26, isOnDark: false),
              ),
              const Gap(SharelySpacing.lg),
              if (devices.isEmpty)
                SharelyButton(
                  label: 'Pair your laptop',
                  variant: SharelyButtonVariant.ink,
                  onPressed: () => context.go(AppRoutes.scan),
                )
              else
                DeviceHeroCard(laptop: devices.last, onSend: null),
            ],
          ),
        ),
      ),
    );
  }
}

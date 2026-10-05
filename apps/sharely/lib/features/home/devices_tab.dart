import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/widgets/paired_device_card.dart';
import 'package:sharely_core/sharely_core.dart';

/// The paired laptop, and the way to forget it.
class DevicesTabView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
      children: [
        Text('Devices', style: textTheme.headlineMedium),
        const SizedBox(height: SharelySpacing.lg),
        if (devices.isEmpty)
          SharelyButton(
            label: 'Pair your laptop',
            variant: SharelyButtonVariant.ink,
            onPressed: () => context.go(AppRoutes.scan),
          ),
        for (final device in devices) ...[
          PairedDeviceCard(device: device),
          const SizedBox(height: SharelySpacing.md),
          SharelyButton(
            label: 'Forget this laptop',
            variant: SharelyButtonVariant.outline,
            onPressed: () => unawaited(_confirmForget(context, ref, device)),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmForget(
    BuildContext context,
    WidgetRef ref,
    PairedDevice device,
  ) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Forget ${device.deviceName}?'),
        content: const Text(
          "You'll need to scan its code again before sending anything.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (isConfirmed != true) return;
    await ref.read(pairedDevicesProvider.notifier).forget(device.deviceId);
    if (context.mounted) context.go(AppRoutes.welcome);
  }
}

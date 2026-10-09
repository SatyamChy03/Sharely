import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_switch.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/home/widgets/settings_group.dart';
import 'package:sharely/features/home/widgets/settings_row.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/widgets/clear_history_dialog.dart';
import 'package:sharely_core/sharely_core.dart';

/// The Settings tab (M14): what this phone accepts, and what it remembers.
class SettingsTabView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final hasActivity = ref.watch(recentTransfersProvider).isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(SharelySpacing.page),
      children: [
        SizedBox(
          height: SharelySizes.minTouchTarget,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ThisDeviceCard(pairedCount: devices.length),
        const SizedBox(height: 14),
        if (devices.isNotEmpty) ...[
          SettingsGroup(
            label: 'Receiving',
            rows: [for (final laptop in devices) _alwaysAcceptRow(ref, laptop)],
          ),
          const SizedBox(height: 14),
        ],
        SettingsGroup(
          label: 'Activity',
          rows: [
            SettingsRow(
              icon: LucideIcons.trash2,
              label: 'Clear activity',
              value: hasActivity ? null : 'Empty',
              onTap: hasActivity
                  ? () => unawaited(_clearActivity(context, ref))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _GeneralGroup(),
      ],
    );
  }

  Widget _alwaysAcceptRow(WidgetRef ref, PairedDevice laptop) {
    final label = 'Always accept from ${laptop.deviceName}';
    return SettingsRow(
      icon: LucideIcons.shieldCheck,
      label: label,
      trailing: SharelySwitch(
        label: label,
        value: laptop.alwaysAccept,
        onChanged: (isOn) => unawaited(
          ref
              .read(pairedDevicesProvider.notifier)
              .setAlwaysAccept(laptop.deviceId, isOn: isOn),
        ),
      ),
    );
  }

  Future<void> _clearActivity(BuildContext context, WidgetRef ref) async {
    if (!await confirmClearHistory(context)) return;
    ref.read(recentTransfersProvider.notifier).clear();
  }
}

class _ThisDeviceCard extends ConsumerWidget {
  const new({required this.pairedCount});

  final int pairedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final name = ref.watch(localHelloProvider).value?.deviceName ?? '';
    final laptops = pairedCount == 1
        ? '1 paired laptop'
        : '$pairedCount '
              'paired laptops';
    return SurfaceCard(
      radius: SharelyRadii.zone,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SharelyColors.elevated,
            ),
            child: Text(
              name.isEmpty ? '' : name[0].toUpperCase(),
              style: textTheme.labelLarge?.copyWith(
                color: SharelyColors.primarySoft,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge,
                ),
                Text(
                  'This phone · $laptops',
                  style: textTheme.bodySmall?.copyWith(
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralGroup extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const SettingsGroup(
      label: 'General',
      rows: [
        SettingsRow(icon: LucideIcons.moon, label: 'Appearance', value: 'Dark'),
        SettingsRow(
          icon: LucideIcons.lock,
          label: 'Who can send to you',
          value: 'Paired only',
        ),
        SettingsRow(
          icon: LucideIcons.info,
          label: 'About',
          value: 'No ads · No account',
        ),
      ],
    );
  }
}

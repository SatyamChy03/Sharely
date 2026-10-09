import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/home/phone_send_actions.dart';
import 'package:sharely/features/home/widgets/connected_laptop_card.dart';
import 'package:sharely/features/home/widgets/home_greeting.dart';
import 'package:sharely/features/home/widgets/phone_tab_bar.dart';
import 'package:sharely/features/home/widgets/received_notes_section.dart';
import 'package:sharely/features/home/widgets/recent_section.dart';
import 'package:sharely/features/home/widgets/send_tiles.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

/// The Home tab (M06): the laptop, send shortcuts and recent transfers.
class HomeTabView extends ConsumerWidget {
  const new({required this.onShowTab, super.key});

  final ValueChanged<HomeTab> onShowTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(laptopConnectionProvider);
    final send = ref.watch(sendProvider);
    final canPick = connection is LaptopConnected && send is SendIdle;
    return ListView(
      padding: const EdgeInsets.all(SharelySpacing.page),
      children: [
        const HomeGreeting(),
        const SizedBox(height: SharelySpacing.page),
        if (connection is LaptopNotPaired)
          SharelyButton(
            label: 'Pair your laptop',
            leadingIcon: LucideIcons.plus,
            onPressed: () => context.go(AppRoutes.scan),
          )
        else
          _LaptopCard(
            connection: connection,
            onChange: () => onShowTab(HomeTab.devices),
          ),
        if (send is! SendIdle) ...[
          const SizedBox(height: SharelySpacing.md),
          _ActiveSendBanner(send: send),
        ],
        const SizedBox(height: SharelySpacing.page),
        const ReceivedNotesSection(),
        Text(
          'What do you want to send?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SharelySpacing.md),
        SendTiles(
          onPhotos: canPick
              ? () => unawaited(
                  pickAndSendFromPhone(context, ref, photosOnly: true),
                )
              : null,
          onFiles: canPick
              ? () => unawaited(
                  pickAndSendFromPhone(context, ref, photosOnly: false),
                )
              : null,
          onLink: connection is LaptopConnected
              ? () => unawaited(
                  openQuickTextSheet(
                    context,
                    ref,
                    connection.laptop.deviceName,
                  ),
                )
              : null,
          onClipboard: connection is LaptopConnected
              ? () => unawaited(sendClipboardFromPhone(context, ref))
              : null,
        ),
        const SizedBox(height: SharelySpacing.page),
        RecentSection(onSeeAll: () => onShowTab(HomeTab.activity)),
      ],
    );
  }
}

class _LaptopCard extends ConsumerWidget {
  const new({required this.connection, required this.onChange});

  final LaptopConnectionState connection;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connector = ref.read(laptopConnectionProvider.notifier);
    return switch (connection) {
      LaptopConnected(:final laptop) => ConnectedLaptopCard(
        laptopName: laptop.deviceName,
        statusLabel: 'Connected · Wi-Fi',
        tone: StatusTone.connected,
        actionLabel: 'Change',
        onAction: onChange,
      ),
      LaptopConnecting(:final laptop) => ConnectedLaptopCard(
        laptopName: laptop.deviceName,
        statusLabel: 'Connecting…',
        tone: StatusTone.connecting,
        actionLabel: 'Change',
        onAction: onChange,
      ),
      LaptopUnreachable(:final laptop) => ConnectedLaptopCard(
        laptopName: laptop.deviceName,
        statusLabel: 'Offline',
        tone: StatusTone.offline,
        detail:
            "Can't reach it. Open Sharely on the laptop and use the same "
            'Wi-Fi.',
        actionLabel: 'Retry',
        isActionPrimary: true,
        onAction: connector.retryNow,
      ),
      LaptopDisconnected(:final laptop) => ConnectedLaptopCard(
        laptopName: laptop.deviceName,
        statusLabel: 'Disconnected',
        tone: StatusTone.offline,
        detail: 'Connect to use this laptop again.',
        actionLabel: 'Connect',
        isActionPrimary: true,
        onAction: connector.connect,
      ),
      LaptopNeedsRepairing(:final laptop) => ConnectedLaptopCard(
        laptopName: laptop.deviceName,
        statusLabel: 'Needs pairing',
        tone: StatusTone.offline,
        detail: "Scan the laptop's code once more to connect.",
        actionLabel: 'Scan again',
        isActionPrimary: true,
        onAction: () => context.go(AppRoutes.scan),
      ),
      LaptopNotPaired() => const SizedBox.shrink(),
    };
  }
}

/// A send that is running or just ended; tapping reopens its screen.
class _ActiveSendBanner extends StatelessWidget {
  const new({required this.send});

  final SendState send;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (send) {
      SendIdle() => ('', StatusTone.offline),
      SendPreparing() || SendAwaitingAcceptance() => (
        'Waiting for laptop…',
        StatusTone.connecting,
      ),
      SendInProgress(isReconnecting: true) => (
        'Reconnecting…',
        StatusTone.connecting,
      ),
      SendInProgress(:final fraction) => (
        'Sending… ${(fraction * 100).floor()}%',
        StatusTone.connected,
      ),
      SendSucceeded() => ('Sent · see details', StatusTone.success),
      SendFailed() => ("Couldn't send · see why", StatusTone.failed),
    };
    return InkWell(
      onTap: () => unawaited(context.push(AppRoutes.sending)),
      borderRadius: const BorderRadius.all(SharelyRadii.tile),
      child: SurfaceCard(
        radius: SharelyRadii.tile,
        color: SharelyColors.elevated,
        borderColor: SharelyColors.lineStrong,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: StatusBadge(label: label, tone: tone, isPlain: true),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: SharelyColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/home/widgets/device_hero_card.dart';
import 'package:sharely/features/home/widgets/quick_text_sheet.dart';
import 'package:sharely/features/home/widgets/received_notes_section.dart';
import 'package:sharely/features/home/widgets/recent_section.dart';
import 'package:sharely/features/home/widgets/send_tiles.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

/// The Home tab: laptop card, quick send tiles and recent transfers.
class HomeTabView extends ConsumerWidget {
  const new({required this.onSeeAll, required this.onSettings, super.key});

  final VoidCallback onSeeAll;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(laptopConnectionProvider);
    final send = ref.watch(sendProvider);
    final canPick = connection is LaptopConnected && send is SendIdle;
    return ListView(
      // Room at the bottom so the floating nav never covers the last row.
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
      children: [
        _Header(onSettings: onSettings),
        const SizedBox(height: SharelySpacing.lg),
        if (connection is LaptopNotPaired)
          SharelyButton(
            label: 'Pair your laptop',
            variant: SharelyButtonVariant.ink,
            onPressed: () => context.go(AppRoutes.scan),
          )
        else
          _LaptopCard(connection: connection, send: send),
        const SizedBox(height: SharelySpacing.lg),
        const ReceivedNotesSection(),
        SendTiles(
          onPhotos: canPick ? () => _pickAndSend(context, ref, true) : null,
          onFiles: canPick ? () => _pickAndSend(context, ref, false) : null,
          onLink: connection is LaptopConnected
              ? () => unawaited(
                  _openQuickText(context, ref, connection.laptop.deviceName),
                )
              : null,
          onClip: connection is LaptopConnected
              ? () => unawaited(_sendClipboard(context, ref))
              : null,
        ),
        const SizedBox(height: SharelySpacing.lg),
        RecentSection(onSeeAll: onSeeAll),
      ],
    );
  }
}

Future<void> _openQuickText(
  BuildContext context,
  WidgetRef ref,
  String laptopName,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: SharelyColors.surface,
    builder: (sheetContext) => QuickTextSheet(
      laptopName: laptopName,
      onSend: (text) => _sendText(context, ref, text),
    ),
  );
}

/// Sends what is on the clipboard; the user asked for it by tapping Clip.
Future<void> _sendClipboard(BuildContext context, WidgetRef ref) async {
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  _sendText(context, ref, clipboard?.text ?? '', emptyNotice: _emptyClipboard);
}

const _emptyClipboard = 'There is no text on the clipboard. Copy some first.';

bool _sendText(
  BuildContext context,
  WidgetRef ref,
  String text, {
  String emptyNotice = 'Type or paste something to send first.',
}) {
  final result = ref.read(sendProvider.notifier).sendText(text);
  final notice = switch (result) {
    QuickTextResult.sent => 'Sent to your laptop.',
    QuickTextResult.empty => emptyNotice,
    QuickTextResult.tooLong =>
      'That is too long to send as text. Save it as a file and send that.',
    QuickTextResult.notConnected =>
      "Your laptop isn't connected. Open Sharely on it and try again.",
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(notice)));
  return result == QuickTextResult.sent;
}

Future<void> _pickAndSend(
  BuildContext context,
  WidgetRef ref,
  bool photosOnly,
) async {
  final notifier = ref.read(sendProvider.notifier);
  final started = await notifier.pickAndSend(photosOnly: photosOnly);
  if (started && context.mounted) await context.push(AppRoutes.sending);
}

class _Header extends StatelessWidget {
  const new({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SharelyWordmark(markSize: 26, isOnDark: false),
        IconButton.filledTonal(
          tooltip: 'Settings',
          onPressed: onSettings,
          style: IconButton.styleFrom(
            backgroundColor: SharelyColors.surface,
            foregroundColor: SharelyColors.ink,
            fixedSize: const Size.square(44),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
          icon: const Icon(LucideIcons.settings, size: 20),
        ),
      ],
    );
  }
}

class _LaptopCard extends ConsumerWidget {
  const new({required this.connection, required this.send});

  final LaptopConnectionState connection;
  final SendState send;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connector = ref.read(laptopConnectionProvider.notifier);
    final (laptopName, status, fixLabel, onFix) = switch (connection) {
      LaptopConnected(:final laptop) => (
        laptop.deviceName,
        'Connected · same Wi-Fi',
        null,
        null,
      ),
      LaptopConnecting(:final laptop) => (
        laptop.deviceName,
        'Connecting…',
        null,
        null,
      ),
      LaptopUnreachable(:final laptop) => (
        laptop.deviceName,
        "Can't reach it. Open Sharely on the laptop and use the same Wi-Fi.",
        'Retry',
        connector.retryNow,
      ),
      LaptopDisconnected(:final laptop) => (
        laptop.deviceName,
        'Disconnected. Connect to use this laptop again.',
        'Connect',
        connector.connect,
      ),
      LaptopNeedsRepairing(:final laptop) => (
        laptop.deviceName,
        "Scan the laptop's code once more to connect.",
        'Scan again',
        () => context.go(AppRoutes.scan),
      ),
      LaptopNotPaired() => ('', '', null, null),
    };
    return DeviceHeroCard(
      laptopName: laptopName,
      status: status,
      isConnected: connection is LaptopConnected,
      fixLabel: fixLabel,
      onFix: onFix,
      sendLabel: _sendLabel(),
      onSend: _sendAction(context, ref),
    );
  }

  String _sendLabel() => switch (send) {
    SendIdle() => 'Send to laptop',
    SendPreparing() || SendAwaitingAcceptance() => 'Waiting for laptop…',
    SendInProgress(isReconnecting: true) => 'Reconnecting…',
    SendInProgress(:final fraction) => 'Sending… ${(fraction * 100).floor()}%',
    SendSucceeded() => 'Sent · see details',
    SendFailed() => "Couldn't send · see why",
  };

  VoidCallback? _sendAction(BuildContext context, WidgetRef ref) {
    // A send that is running or just ended reopens its screen.
    if (send is! SendIdle) {
      return () => unawaited(context.push(AppRoutes.sending));
    }
    if (connection is! LaptopConnected) return null;
    return () => unawaited(_pickAndSend(context, ref, false));
  }
}

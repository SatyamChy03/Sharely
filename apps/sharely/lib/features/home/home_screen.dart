import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/home/widgets/device_hero_card.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

/// Phone home: the paired laptop, its live status, and Send.
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Coming back to the app is when a reconnect is most likely to work.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(laptopConnectionProvider.notifier).retryNow(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(laptopConnectionProvider);
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
              if (connection is LaptopNotPaired)
                SharelyButton(
                  label: 'Pair your laptop',
                  variant: SharelyButtonVariant.ink,
                  onPressed: () => context.go(AppRoutes.scan),
                )
              else
                _LaptopCard(connection: connection),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaptopCard extends ConsumerWidget {
  const new({required this.connection});

  final LaptopConnectionState connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSendIdle = ref.watch(sendProvider) is SendIdle;
    final connector = ref.read(laptopConnectionProvider.notifier);
    final (laptopName, status, fixLabel, onFix) = switch (connection) {
      LaptopConnected(:final laptop) => (
        laptop.deviceName,
        'Connected',
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
      LaptopNeedsRepairing(:final laptop) => (
        laptop.deviceName,
        "Scan the laptop's code once more to connect.",
        'Scan again',
        () => context.go(AppRoutes.scan),
      ),
      LaptopNotPaired() => ('', '', null, null),
    };
    final canSend = connection is LaptopConnected && isSendIdle;
    return DeviceHeroCard(
      laptopName: laptopName,
      status: status,
      isConnected: connection is LaptopConnected,
      fixLabel: fixLabel,
      onFix: onFix,
      onSend: canSend ? () => _pickAndSend(context, ref) : null,
    );
  }

  Future<void> _pickAndSend(BuildContext context, WidgetRef ref) async {
    final started = await ref.read(sendProvider.notifier).pickAndSend();
    if (started && context.mounted) await context.push(AppRoutes.sending);
  }
}

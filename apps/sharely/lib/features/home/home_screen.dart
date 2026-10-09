import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/home/devices_tab.dart';
import 'package:sharely/features/home/history_tab.dart';
import 'package:sharely/features/home/home_tab.dart';
import 'package:sharely/features/home/widgets/pill_nav.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/widgets/laptop_offers_overlay.dart';

/// Phone home shell: Home, History and Devices under one floating nav.
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycleListener;
  HomeTab _tab = HomeTab.home;

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

  void _showTab(HomeTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _tab.index,
              children: [
                HomeTabView(
                  onSeeAll: () => _showTab(HomeTab.history),
                  onSettings: () => _showTab(HomeTab.devices),
                ),
                const HistoryTabView(),
                const DevicesTabView(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: SharelySpacing.lg + 4,
              child: Center(
                child: PillNav(current: _tab, onSelected: _showTab),
              ),
            ),
            const Positioned.fill(child: LaptopOffersOverlay()),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/home/activity_tab.dart';
import 'package:sharely/features/home/devices_tab.dart';
import 'package:sharely/features/home/home_tab.dart';
import 'package:sharely/features/home/send_tab.dart';
import 'package:sharely/features/home/settings_tab.dart';
import 'package:sharely/features/home/widgets/phone_tab_bar.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/widgets/laptop_offers_overlay.dart';

/// Phone shell: five sections over one bottom tab bar.
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
    LaptopConnectionController connection() =>
        ref.read(laptopConnectionProvider.notifier);
    // A picker or another app in front pauses Sharely; the laptop is told,
    // and the link is checked the moment the app is back, not assumed.
    _lifecycleListener = AppLifecycleListener(
      onHide: () => connection().reportOnScreen(isOnScreen: false),
      onShow: () => connection().reportOnScreen(isOnScreen: true),
      onResume: () => connection().ensureLinked(),
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
    // The offer sheet sits over the tab bar too, so nothing else is tappable.
    return Stack(
      children: [
        Scaffold(
          bottomNavigationBar: PhoneTabBar(current: _tab, onSelected: _showTab),
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab.index,
              children: [
                HomeTabView(onShowTab: _showTab),
                const SendTabView(),
                const ActivityTabView(),
                const DevicesTabView(),
                const SettingsTabView(),
              ],
            ),
          ),
        ),
        const Positioned.fill(child: LaptopOffersOverlay()),
      ],
    );
  }
}

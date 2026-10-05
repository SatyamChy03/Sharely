import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/features/home/home_screen.dart';
import 'package:sharely/features/onboarding/welcome_screen.dart';
import 'package:sharely/features/pairing/connected_screen.dart';
import 'package:sharely/features/pairing/laptop_pairing_screen.dart';
import 'package:sharely/features/pairing/scan_screen.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/sending_screen.dart';

/// Whether this device plays the laptop role. Overridable in tests.
final isDesktopRoleProvider = Provider<bool>((ref) => isDesktopRole);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: _initialLocation(ref),
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.connected,
        builder: (context, state) => const ConnectedScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.sending,
        builder: (context, state) => const SendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.laptopPairing,
        builder: (context, state) => const LaptopPairingScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String _initialLocation(Ref ref) {
  if (ref.read(isDesktopRoleProvider)) return AppRoutes.laptopPairing;
  final pairedDevices = ref.read(pairedDevicesProvider).value ?? const [];
  return pairedDevices.isEmpty ? AppRoutes.welcome : AppRoutes.home;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/features/home/home_screen.dart';
import 'package:sharely/features/onboarding/welcome_screen.dart';
import 'package:sharely/features/pairing/connected_screen.dart';
import 'package:sharely/features/pairing/laptop_pairing_screen.dart';
import 'package:sharely/features/pairing/scan_screen.dart';

/// Whether this device plays the laptop role. Overridable in tests.
final isDesktopRoleProvider = Provider<bool>((ref) => isDesktopRole);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ref.read(isDesktopRoleProvider)
        ? AppRoutes.laptopPairing
        : AppRoutes.welcome,
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
        path: AppRoutes.laptopPairing,
        builder: (context, state) => const LaptopPairingScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/features/onboarding/laptop_welcome_screen.dart';

Future<void> _pumpWelcome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.laptopWelcome,
    routes: [
      GoRoute(
        path: AppRoutes.laptopWelcome,
        builder: (context, state) => const LaptopWelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.laptopPairing,
        builder: (context, state) => const Text('pairing'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

void main() {
  for (final size in const [Size(1280, 800), Size(640, 700)]) {
    testWidgets('the laptop welcome explains pairing at ${size.width} px', (
      tester,
    ) async {
      await _pumpWelcome(tester, size);

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Scan the code on this screen'), findsOneWidget);
      expect(find.textContaining('Direct and private.'), findsOneWidget);
    });
  }

  testWidgets('"Pair a phone" opens the pairing code', (tester) async {
    await _pumpWelcome(tester, const Size(1280, 800));

    await tester.tap(find.text('Pair a phone'));
    await tester.pumpAndSettle();

    expect(find.text('pairing'), findsOneWidget);
  });
}

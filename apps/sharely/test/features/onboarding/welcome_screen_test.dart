import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/sharely_app.dart';
import 'package:sharely/features/pairing/scan_screen.dart';

void main() {
  Future<void> pumpSharelyApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: SharelyApp()));
    // The orbit animation loops forever, so pump a fixed time, not settle.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('welcome screen shows the promise and trust chips', (
    tester,
  ) async {
    await pumpSharelyApp(tester);

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('No ads'), findsOneWidget);
    expect(find.text('No account'), findsOneWidget);
    expect(find.text('No cloud'), findsOneWidget);
  });

  testWidgets('get started opens the scan step', (tester) async {
    await pumpSharelyApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ScanScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/laptop/laptop_activity_view.dart';
import 'package:sharely/features/laptop/laptop_home_screen.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/transfers_by_day.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely_core/sharely_core.dart';

final _phone = PairedDevice(
  deviceId: 'phone_0123456789abc',
  deviceName: 'Motorola Edge',
  platform: DevicePlatform.android,
  authToken: 'auth_0123456789abcdef',
  pairedAt: DateTime.utc(2026, 10, 5),
);

class _FixedLaptopPairing extends LaptopPairingController {
  @override
  Future<LaptopPairingState> build() async => LaptopPairedWithPhone(_phone);
}

class _FixedPairedDevices extends PairedDevicesNotifier {
  @override
  Future<List<PairedDevice>> build() async => [_phone];
}

class _NoConnectedPhones extends ConnectedPhones {
  @override
  Set<String> build() => const {};
}

class _NoIncoming extends IncomingTransfersController {
  @override
  List<IncomingTransferView> build() => const [];
}

RecentTransfer _received(String name, int sizeBytes, DateTime finishedAt) {
  return RecentTransfer(
    name: name,
    sizeBytes: sizeBytes,
    direction: TransferDirection.received,
    finishedAt: finishedAt,
  );
}

Future<ProviderContainer> _pumpLaptopHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      laptopPairingProvider.overrideWith(_FixedLaptopPairing.new),
      pairedDevicesProvider.overrideWith(_FixedPairedDevices.new),
      connectedPhonesProvider.overrideWith(_NoConnectedPhones.new),
      incomingTransfersProvider.overrideWith(_NoIncoming.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LaptopHomeScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  testWidgets('Activity lists every transfer by day with its time', (
    tester,
  ) async {
    final container = await _pumpLaptopHome(tester);
    final finishedAt = DateTime.now();
    container.read(recentTransfersProvider.notifier).record([
      _received('holiday.png', 2500000, finishedAt),
      _received('notes.pdf', 500000, finishedAt),
    ]);
    await tester.pump();

    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LaptopActivityView), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('holiday.png'), findsOneWidget);
    expect(find.text(formatClockTime(finishedAt)), findsNWidgets(2));
  });

  testWidgets('View all on Home opens Activity, and Home leads back', (
    tester,
  ) async {
    final container = await _pumpLaptopHome(tester);
    container.read(recentTransfersProvider.notifier).record([
      _received('holiday.png', 2500000, DateTime.now()),
    ]);
    await tester.pump();

    await tester.tap(find.text('View all'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LaptopActivityView), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Send files to'), findsOneWidget);
  });

  testWidgets('an empty Activity says what will appear', (tester) async {
    await _pumpLaptopHome(tester);

    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No transfers yet'), findsOneWidget);
  });

  test('transfers are grouped into today, yesterday and earlier', () {
    final now = DateTime(2026, 10, 7, 12);
    final groups = groupTransfersByDay([
      _received('a.png', 1, DateTime(2026, 10, 7, 9)),
      _received('b.png', 1, DateTime(2026, 10, 6, 23)),
      _received('c.png', 1, DateTime(2026, 10, 2)),
    ], now: now);

    expect(
      [for (final group in groups) group.label],
      ['TODAY', 'YESTERDAY', 'EARLIER'],
    );
  });

  testWidgets('one entry can be removed and the rest cleared', (tester) async {
    final container = await _pumpLaptopHome(tester);
    container.read(recentTransfersProvider.notifier).record([
      _received('holiday.png', 2500000, DateTime.now()),
      _received('notes.pdf', 500000, DateTime.now()),
    ]);
    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Remove from activity').first);
    await tester.pump();
    expect(find.text('holiday.png'), findsNothing);
    expect(find.text('notes.pdf'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Clear'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No transfers yet'), findsOneWidget);
  });

  testWidgets('declining the prompt keeps the activity', (tester) async {
    final container = await _pumpLaptopHome(tester);
    container.read(recentTransfersProvider.notifier).record([
      _received('holiday.png', 2500000, DateTime.now()),
    ]);
    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Clear all'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Keep'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('holiday.png'), findsOneWidget);
  });
}

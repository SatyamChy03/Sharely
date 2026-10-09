import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/home/home_screen.dart';
import 'package:sharely/features/transfer/sending_screen.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfers_overlay.dart';
import 'package:sharely_core/sharely_core.dart';

final _laptop = PairedDevice(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'satyam-LOQ',
  platform: DevicePlatform.linux,
  authToken: 'auth_0123456789abcdef',
  pairedAt: DateTime.utc(2026, 10, 5),
);

class _FixedConnection extends LaptopConnectionController {
  new(this._state);

  final LaptopConnectionState _state;

  @override
  LaptopConnectionState build() => _state;
}

class _FixedSend extends SendController {
  new(this._state);

  final SendState _state;

  @override
  SendState build() => _state;
}

class _FixedIncoming extends IncomingTransfersController {
  new(this._views);

  final List<IncomingTransferView> _views;

  @override
  List<IncomingTransferView> build() => _views;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required List<Override> overrides,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  // flutter_animate starts with a zero-length timer; flush it.
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('home explains an unreachable laptop and disables Send', (
    tester,
  ) async {
    await _pump(
      tester,
      const HomeScreen(),
      overrides: [
        laptopConnectionProvider.overrideWith(
          () => _FixedConnection(LaptopUnreachable(_laptop)),
        ),
      ],
    );

    expect(find.text('satyam-LOQ'), findsOneWidget);
    expect(find.textContaining("Can't reach it"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final send = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Send to laptop'),
        matching: find.byType(TextButton),
      ),
    );
    expect(send.onPressed, isNull);
  });

  final sendScreens = <String, (SendState, List<String>)>{
    'waiting': (
      const SendAwaitingAcceptance(
        files: [
          (name: 'IMG_2051.jpg', sizeBytes: 2100000),
          (name: 'IMG_2052.jpg', sizeBytes: 2100000),
        ],
      ),
      [
        'Sending to',
        'Accept on your laptop to start.',
        'IMG_2051.jpg',
        'Cancel',
      ],
    ),
    'in progress': (
      const SendInProgress(
        files: [(name: 'Trip.mp4', sizeBytes: 10000000)],
        bytesSent: 2500000,
        bytesPerSecond: 5000000,
      ),
      [
        '25%',
        '5.0 MB/s',
        '0 / 1',
        '~2 s',
        'Keeps going if you leave this screen',
      ],
    ),
    'succeeded': (
      const SendSucceeded(files: [(name: 'a.jpg', sizeBytes: 2048)]),
      ['100%', '1 / 1', 'done', 'Done'],
    ),
    'declined': (
      const SendFailed(
        files: [(name: 'a.jpg', sizeBytes: 2048)],
        reason: TransferFailure.rejected,
      ),
      [describeSendFailure(TransferFailure.rejected), 'Back to home'],
    ),
  };
  for (final MapEntry(key: name, value: (state, texts))
      in sendScreens.entries) {
    testWidgets('the sending screen shows the $name state', (tester) async {
      await _pump(
        tester,
        const SendingScreen(),
        overrides: [sendProvider.overrideWith(() => _FixedSend(state))],
      );

      for (final text in texts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });
  }

  testWidgets('the laptop shows an incoming offer with Accept and Decline', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: Stack(children: [IncomingTransfersOverlay()])),
      size: const Size(1280, 800),
      overrides: [
        incomingTransfersProvider.overrideWith(
          () => _FixedIncoming(const [
            IncomingTransferView(
              transferId: 'transfer_0123456789',
              senderId: 'phone_0123456789abc',
              senderName: 'Motorola moto g54 5G',
              fileNames: ['IMG_2041.jpg', 'IMG_2042.jpg'],
              fileSizes: [2100000, 2100000],
              totalBytes: 4200000,
            ),
          ]),
        ),
      ],
    );

    expect(
      find.text('Motorola moto g54 5G is sending 2 files'),
      findsOneWidget,
    );
    expect(find.text('4.2 MB'), findsOneWidget);
    expect(find.text('Always accept from this phone'), findsOneWidget);
    expect(find.text('IMG_2041.jpg'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });
}

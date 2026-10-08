import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/home/home_screen.dart';
import 'package:sharely/features/home/widgets/quick_text_sheet.dart';
import 'package:sharely/features/laptop/widgets/phone_send_card.dart';
import 'package:sharely/features/laptop/widgets/quick_text_bar.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/laptop_messages.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/state/received_note.dart';
import 'package:sharely/features/transfer/state/received_notes.dart';
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
  @override
  LaptopConnectionState build() => LaptopUnreachable(_laptop);
}

class _FixedOffers extends LaptopOffersController {
  new(this._views);

  final List<IncomingTransferView> _views;
  final decisions = <String>[];

  @override
  List<IncomingTransferView> build() => _views;

  @override
  void accept(String transferId, {bool alwaysFromLaptop = false}) =>
      decisions.add('accept $transferId always=$alwaysFromLaptop');

  @override
  void decline(String transferId) => decisions.add('decline $transferId');
}

class _NoIncoming extends IncomingTransfersController {
  @override
  List<IncomingTransferView> build() => const [];
}

class _FixedNotes extends ReceivedNotes {
  new(this._notes) : super(laptopMessagesProvider);

  final List<ReceivedNote> _notes;

  @override
  List<ReceivedNote> build() => _notes;
}

IncomingTransferView _view({
  IncomingTransferStage stage = IncomingTransferStage.offered,
  int bytesReceived = 0,
  TransferFailure? failure,
}) => IncomingTransferView(
  transferId: 'transfer_0123456789',
  senderId: _laptop.deviceId,
  senderName: _laptop.deviceName,
  fileNames: const ['app-release.apk', 'server.log'],
  fileSizes: const [48000000, 2000000],
  totalBytes: 50000000,
  stage: stage,
  bytesReceived: bytesReceived,
  failure: failure,
);

Future<void> _pumpHome(
  WidgetTester tester, {
  List<IncomingTransferView> offers = const [],
  List<ReceivedNote> notes = const [],
  _FixedOffers? controller,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        laptopConnectionProvider.overrideWith(_FixedConnection.new),
        laptopOffersProvider.overrideWith(
          () => controller ?? _FixedOffers(offers),
        ),
        receivedNotesProvider.overrideWith(() => _FixedNotes(notes)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  // flutter_animate starts with a zero-length timer; flush it, then let the
  // sheet finish sliding into place.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpWidget(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('an offer from the laptop asks before anything is saved', (
    tester,
  ) async {
    final controller = _FixedOffers([_view()]);
    await _pumpHome(tester, controller: controller);

    expect(find.text('satyam-LOQ is sending'), findsOneWidget);
    expect(find.textContaining('2 files'), findsOneWidget);
    expect(find.text('app-release.apk'), findsOneWidget);
    expect(find.text('APK'), findsOneWidget);
    expect(find.text('Downloads/Sharely'), findsOneWidget);

    await tester.tap(find.text('Always accept from this laptop'));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    expect(controller.decisions, ['accept transfer_0123456789 always=true']);

    await tester.tap(find.text('Decline'));
    expect(controller.decisions.last, 'decline transfer_0123456789');
  });

  testWidgets('a running download shows progress and a way to cancel', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      offers: [
        _view(stage: IncomingTransferStage.receiving, bytesReceived: 25000000),
      ],
    );

    expect(find.text('Receiving from satyam-LOQ'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('a stopped download says why', (tester) async {
    await _pumpHome(
      tester,
      offers: [
        _view(
          stage: IncomingTransferStage.failed,
          failure: TransferFailure.cancelled,
        ),
      ],
    );

    expect(find.text('Transfer stopped'), findsOneWidget);
    expect(
      find.text(
        describeReceiveFailure(TransferFailure.cancelled, 'satyam-LOQ'),
      ),
      findsOneWidget,
    );
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('an OTP from the laptop can be copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        final arguments = call.arguments;
        if (call.method == 'Clipboard.setData' && arguments is Map) {
          copied = arguments['text'] as String?;
        }
        return null;
      },
    );
    await _pumpHome(tester, notes: const [ReceivedNote(id: 0, text: '482913')]);

    expect(find.text('From your laptop'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, '482913');
    expect(find.text('Copied.'), findsOneWidget);
  });

  testWidgets('a link from the laptop offers to open it', (tester) async {
    await _pumpHome(
      tester,
      notes: [
        ReceivedNote(
          id: 0,
          text: 'https://example.com/x',
          link: Uri.parse('https://example.com/x'),
        ),
      ],
    );

    expect(find.text('Link from your laptop'), findsOneWidget);
    expect(find.text('https://example.com/x'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('the laptop card follows a send from waiting to done', (
    tester,
  ) async {
    const files = [(name: 'video.mp4', sizeBytes: 4000000000)];
    var cancels = 0;
    var dismissals = 0;
    Future<void> show(SendWithFiles send) => _pumpWidget(
      tester,
      PhoneSendCard(
        send: send,
        phoneName: 'Pixel 8',
        onCancel: () => cancels++,
        onDismiss: () => dismissals++,
      ),
    );

    await show(const SendAwaitingAcceptance(files: files));
    expect(find.text('Waiting for Pixel 8 to accept'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);

    await show(
      const SendInProgress(
        files: files,
        bytesSent: 1000000000,
        bytesPerSecond: 50000000,
      ),
    );
    expect(find.text('Sending 1 file to Pixel 8'), findsOneWidget);
    expect(find.textContaining('1.0 GB of 4.0 GB'), findsOneWidget);
    expect(find.textContaining('50.0 MB/s'), findsOneWidget);

    await show(
      const SendFailed(files: files, reason: TransferFailure.rejected),
    );
    expect(find.text('Pixel 8 declined the files.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    expect(dismissals, 1);
  });

  testWidgets('the phone sheet sends what was typed and then closes', (
    tester,
  ) async {
    var isAccepted = false;
    final sent = <String>[];
    await _pumpWidget(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => QuickTextSheet(
              laptopName: 'satyam-LOQ',
              onSend: (text) {
                sent.add(text);
                return isAccepted;
              },
            ),
          ),
          child: const Text('Link'),
        ),
      ),
    );
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(find.text('Send to satyam-LOQ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Send to satyam-LOQ'), findsOneWidget);

    isAccepted = true;
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, ['https://example.com', 'https://example.com']);
    expect(find.text('Send to satyam-LOQ'), findsNothing);
  });

  testWidgets('the laptop shows an OTP from the phone as a notification', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incomingTransfersProvider.overrideWith(_NoIncoming.new),
          phoneNotesProvider.overrideWith(
            () => _FixedNotes(const [ReceivedNote(id: 0, text: '771204')]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [IncomingTransfersOverlay()])),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('From your phone'), findsOneWidget);
    expect(find.text('771204'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('the text bar clears only when the text went out', (
    tester,
  ) async {
    var isAccepted = false;
    final sent = <String>[];
    await _pumpWidget(
      tester,
      QuickTextBar(
        onSend: (text) {
          sent.add(text);
          return isAccepted;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), '482913');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('482913'), findsOneWidget);

    isAccepted = true;
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sent, ['482913', '482913']);
    expect(find.text('482913'), findsNothing);
  });
}

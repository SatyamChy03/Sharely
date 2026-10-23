import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import 'transfer_harness.dart';

// Short stand-ins for the real limits, so a pause takes milliseconds.
const _checkEvery = Duration(milliseconds: 50);
const _onScreenLimit = Duration(milliseconds: 300);
const _offScreenLimit = Duration(seconds: 3);
const _pause = Duration(milliseconds: 1200);

/// A phone whose app Android has paused: the socket stays open, but the
/// app reads nothing and answers nothing, exactly as while a picker is up.
class _PausablePhone {
  new _(this._socket);

  final WebSocket _socket;
  final _closed = Completer<void>();

  bool get isOpen => !_closed.isCompleted;

  static Future<_PausablePhone> connect(TransferHarness harness) async {
    final connected = harness.receiver.hub.connects.first;
    final socket = await WebSocket.connect(
      harness.endpoint.webSocketUri('/v1/control').toString(),
      headers: harness.authHeadersFor(phone),
      customClient: harness.endpoint.createHttpClient(),
    );
    final paused = _PausablePhone._(socket);
    socket.listen((_) {}, onDone: paused._closed.complete);
    addTearDown(socket.close);
    await connected;
    return paused;
  }

  void say(ProtocolMessage message) =>
      _socket.add(MessageCodec.encode(message));
}

void main() {
  late TransferHarness harness;

  setUp(() async {
    harness = await TransferHarness.start(
      hub: ControlHub(
        checkEvery: _checkEvery,
        silenceLimit: _onScreenLimit,
        offScreenSilenceLimit: _offScreenLimit,
      ),
    );
  });

  ControlHub hub() => harness.receiver.hub;

  test(
    'the original failure: a phone paused without saying so is dropped',
    () async {
      final paused = await _PausablePhone.connect(harness);

      await Future<void>.delayed(_pause);

      expect(hub().isConnected(phone.deviceId), isFalse);
      expect(paused.isOpen, isFalse);
    },
  );

  test(
    'a phone that said it went off screen keeps its link through a pause',
    () async {
      final paused = await _PausablePhone.connect(harness)
        ..say(const PresenceMessage(isOnScreen: false));

      await Future<void>.delayed(_pause);

      expect(hub().isConnected(phone.deviceId), isTrue);
      expect(paused.isOpen, isTrue);
    },
  );

  test('back on screen, the shorter limit applies again', () async {
    final paused = await _PausablePhone.connect(harness)
      ..say(const PresenceMessage(isOnScreen: false))
      ..say(const PresenceMessage(isOnScreen: true));

    await Future<void>.delayed(_pause);

    expect(hub().isConnected(phone.deviceId), isFalse);
    expect(paused.isOpen, isFalse);
  });

  test(
    'a phone gone for good is still dropped after the longer limit',
    () async {
      final paused = await _PausablePhone.connect(harness);
      paused.say(const PresenceMessage(isOnScreen: false));

      await hub().disconnects.first.timeout(_offScreenLimit * 2);
    },
  );

  test('closing the app off screen still shows at once', () async {
    final paused = await _PausablePhone.connect(harness)
      ..say(const PresenceMessage(isOnScreen: false));
    final gone = hub().disconnects.first;
    final sinceClosed = Stopwatch()..start();

    await paused._socket.close();
    await gone.timeout(const Duration(seconds: 2));

    expect(sinceClosed.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('presence is handled by the link and never reaches the app', () async {
    final seen = hub().messages.toList();
    final paused = await _PausablePhone.connect(harness)
      ..say(const PresenceMessage(isOnScreen: false))
      ..say(const TextContentMessage.text('hi'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await paused._socket.close();
    await harness.receiver.close();

    final messages = await seen;
    expect(messages.map((m) => m.message), [isA<TextContentMessage>()]);
  });

  test('a link in use while files move stays up', () async {
    harness.acceptEveryOffer();
    final connection = await harness.connect();
    final file = await harness.writeFile('a.bin', List.filled(64 * 1024, 3));

    final transfer = OutgoingTransfer.start(
      files: [file],
      connection: connection,
      endpoint: harness.endpoint,
      authHeaders: harness.authHeadersFor(phone),
    );
    await transfer.done;
    await Future<void>.delayed(_pause);

    expect(connection.isOpen, isTrue);
    expect(hub().isConnected(phone.deviceId), isTrue);
  });

  group('the presence message', () {
    test('round trips', () {
      for (final isOnScreen in [true, false]) {
        final decoded = MessageCodec.decode(
          MessageCodec.encode(PresenceMessage(isOnScreen: isOnScreen)),
        );
        expect(decoded, isA<PresenceMessage>());
        expect((decoded as PresenceMessage).isOnScreen, isOnScreen);
      }
    });

    final invalid = {
      'a missing flag': {'type': 'presence'},
      'a flag that is not true or false': {
        'type': 'presence',
        'onScreen': 'no',
      },
      'an extra field': {'type': 'presence', 'onScreen': true, 'limit': 9999},
    };
    for (final MapEntry(key: description, value: json) in invalid.entries) {
      test('rejects $description', () {
        expect(
          () => MessageCodec.decode(jsonEncode(json)),
          throwsA(isA<ProtocolException>()),
        );
      });
    }
  });

  group('LinkLiveness', () {
    test('a pause on this device is not blamed on the peer', () async {
      var now = DateTime.utc(2026, 10, 22);
      var pings = 0;
      var isClosed = false;
      final liveness = LinkLiveness(
        sendPing: () => pings++,
        closeAsDead: () => isClosed = true,
        clock: () => now,
        checkEvery: _checkEvery,
        allowedSilence: _onScreenLimit,
      );
      addTearDown(liveness.stop);

      // Thawed after a long freeze: the peer's answers are still unread.
      now = now.add(const Duration(minutes: 5));
      await Future<void>.delayed(_checkEvery * 2);

      expect(isClosed, isFalse);
      expect(pings, greaterThan(0));
    });

    test('a peer that stays silent while this device runs is dead', () async {
      var now = DateTime.utc(2026, 10, 22);
      var isClosed = false;
      final ticker = Timer.periodic(
        _checkEvery,
        (_) => now = now.add(_checkEvery),
      );
      addTearDown(ticker.cancel);
      final liveness = LinkLiveness(
        sendPing: () {},
        closeAsDead: () => isClosed = true,
        clock: () => now,
        checkEvery: _checkEvery,
        allowedSilence: _onScreenLimit,
      );
      addTearDown(liveness.stop);

      await Future<void>.delayed(_onScreenLimit * 3);

      expect(isClosed, isTrue);
    });

    test('hearing from the peer keeps the link', () async {
      var isClosed = false;
      final liveness = LinkLiveness(
        sendPing: () {},
        closeAsDead: () => isClosed = true,
        checkEvery: _checkEvery,
        allowedSilence: _onScreenLimit,
      );
      addTearDown(liveness.stop);
      final heard = Timer.periodic(_checkEvery, (_) => liveness.recordHeard());
      addTearDown(heard.cancel);

      await Future<void>.delayed(_onScreenLimit * 3);

      expect(isClosed, isFalse);
    });
  });
}

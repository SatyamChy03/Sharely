import 'dart:async';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

const _authToken = 'auth_0123456789abcdef0123456789abcdef';

final phone = PairedDevice(
  deviceId: 'phone_0123456789abc',
  deviceName: 'Phone',
  platform: DevicePlatform.android,
  authToken: _authToken,
  pairedAt: DateTime.utc(2026, 10, 5),
);

final otherPhone = PairedDevice(
  deviceId: 'other_0123456789abc',
  deviceName: 'Other phone',
  platform: DevicePlatform.android,
  authToken: 'auth_fedcba9876543210fedcba9876543210',
  pairedAt: DateTime.utc(2026, 10, 5),
);

/// A real laptop server on loopback, with a temp save folder and files.
class TransferHarness {
  new _(this.server, this.receiver, this.sender, this.workDirectory);

  final SharelyServer server;
  final TransferReceiver receiver;
  final TransferSender sender;
  final Directory workDirectory;

  Directory get saveDirectory => Directory('${workDirectory.path}/received');

  DeviceEndpoint get endpoint =>
      DeviceEndpoint(host: server.address, port: server.port);

  static Future<TransferHarness> start({
    Duration decisionTimeout = const Duration(seconds: 5),
    Duration resumeWindow = const Duration(seconds: 20),
    Duration dataIdleTimeout = defaultDataIdleTimeout,
  }) async {
    final workDirectory = await Directory.systemTemp.createTemp('sharely_');
    final receiver = TransferReceiver(
      saveDirectory: () async => Directory('${workDirectory.path}/received'),
      resumeWindow: resumeWindow,
      dataIdleTimeout: dataIdleTimeout,
    );
    final sender = TransferSender(
      hub: receiver.hub,
      decisionTimeout: decisionTimeout,
      resumeWindow: resumeWindow,
    );
    final pairedDevices = {
      for (final device in [phone, otherPhone]) device.deviceId: device,
    };
    final server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      pairingHandler: PairingRequestHandler(
        currentSession: () => null,
        localHello: const HelloMessage(
          deviceId: 'laptop_0123456789ab',
          deviceName: 'Laptop',
          platform: DevicePlatform.linux,
        ),
        onPaired: (_) {},
      ),
      transfers: (
        receiver: receiver,
        sender: sender,
        findPairedDevice: pairedDevices.get,
      ),
    );
    final harness = TransferHarness._(server, receiver, sender, workDirectory);
    addTearDown(harness.stop);
    return harness;
  }

  Map<String, String> authHeadersFor(PairedDevice device) => buildAuthHeaders(
    localDeviceId: device.deviceId,
    authToken: device.authToken,
  );

  Future<ControlConnection> connect([PairedDevice? device]) async {
    final connection = await ControlConnection.connect(
      endpoint,
      authHeaders: authHeadersFor(device ?? phone),
    );
    addTearDown(connection.close);
    // Let the server adopt the connection before messages flow.
    await pumpEventQueue();
    return connection;
  }

  Future<OutgoingFile> writeFile(String name, List<int> bytes) async {
    final file = File('${workDirectory.path}/$name');
    await file.writeAsBytes(bytes);
    return await OutgoingFile.fromPath(file.path);
  }

  List<File> savedFiles() {
    if (!saveDirectory.existsSync()) return const [];
    return saveDirectory.listSync().whereType<File>().toList();
  }

  /// Accepts every offer as soon as it arrives.
  void acceptEveryOffer() {
    receiver.events.whereType<IncomingOfferReceived>().listen(
      (event) => receiver.accept(event.transferId),
    );
  }

  Future<void> stop() async {
    await sender.close();
    await receiver.close();
    await server.stop();
    await workDirectory.delete(recursive: true);
  }
}

extension on Map<String, PairedDevice> {
  PairedDevice? get(String deviceId) => this[deviceId];
}

extension WhereTypeStream<T> on Stream<T> {
  Stream<S> whereType<S>() => where((event) => event is S).cast<S>();
}

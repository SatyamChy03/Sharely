import 'package:meta/meta.dart';
import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';

/// A device this one trusts, with the long-term secret both sides share.
@immutable
final class PairedDevice {
  const new({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.authToken,
    required this.pairedAt,
    this.endpoint,
  });

  factory fromHello(
    HelloMessage hello, {
    required String authToken,
    required DateTime pairedAt,
    DeviceEndpoint? endpoint,
  }) {
    return PairedDevice(
      deviceId: hello.deviceId,
      deviceName: hello.deviceName,
      platform: hello.platform,
      authToken: authToken,
      pairedAt: pairedAt,
      endpoint: endpoint,
    );
  }

  final String deviceId;
  final String deviceName;
  final DevicePlatform platform;
  final String authToken;
  final DateTime pairedAt;

  /// Known only for laptops, whose servers the phone connects to.
  final DeviceEndpoint? endpoint;

  PairedDevice copyWith({String? deviceName, DeviceEndpoint? endpoint}) {
    return PairedDevice(
      deviceId: deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform,
      authToken: authToken,
      pairedAt: pairedAt,
      endpoint: endpoint ?? this.endpoint,
    );
  }

  // The auth token is deliberately left out so it never reaches a log.
  @override
  String toString() => 'PairedDevice($deviceName, ${platform.name})';
}

import 'package:meta/meta.dart';
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
  });

  factory fromHello(
    HelloMessage hello, {
    required String authToken,
    required DateTime pairedAt,
  }) {
    return PairedDevice(
      deviceId: hello.deviceId,
      deviceName: hello.deviceName,
      platform: hello.platform,
      authToken: authToken,
      pairedAt: pairedAt,
    );
  }

  final String deviceId;
  final String deviceName;
  final DevicePlatform platform;
  final String authToken;
  final DateTime pairedAt;

  // The auth token is deliberately left out so it never reaches a log.
  @override
  String toString() => 'PairedDevice($deviceName, ${platform.name})';
}

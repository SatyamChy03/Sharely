part of 'protocol_message.dart';

/// First message on a connection: who the peer is and which protocol it speaks.
final class HelloMessage extends ProtocolMessage {
  const new({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.protocolVersion = ProtocolLimits.protocolVersion,
  });

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {
      'type',
      'deviceId',
      'name',
      'platform',
      'protocolVersion',
    });
    return HelloMessage(
      deviceId: fields.id('deviceId'),
      deviceName: fields.string(
        'name',
        maxLength: ProtocolLimits.maxDeviceNameChars,
      ),
      platform: _parsePlatform(fields.string('platform', maxLength: 16)),
      protocolVersion: fields.integer('protocolVersion', min: 1, max: 1000),
    );
  }

  final String deviceId;
  final String deviceName;
  final DevicePlatform platform;
  final int protocolVersion;

  @override
  MessageType get type => MessageType.hello;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'deviceId': deviceId,
    'name': deviceName,
    'platform': platform.name,
    'protocolVersion': protocolVersion,
  };

  static DevicePlatform _parsePlatform(String wireName) {
    final platform = DevicePlatform.fromWireName(wireName);
    if (platform == null) throw const ProtocolException('Unknown platform');
    return platform;
  }
}

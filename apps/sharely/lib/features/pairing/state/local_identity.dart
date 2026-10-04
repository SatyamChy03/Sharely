import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely_core/sharely_core.dart';

final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

// Regenerated each launch until paired devices are persisted securely.
final String _launchDeviceId = generateSecureId();

/// How this device introduces itself to the other side.
final localHelloProvider = FutureProvider<HelloMessage>((ref) async {
  return HelloMessage(
    deviceId: _launchDeviceId,
    deviceName: _cleanDeviceName(await _readDeviceName()),
    platform: currentDevicePlatform,
  );
});

Future<String> _readDeviceName() async {
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}';
  }
  if (Platform.isIOS) return (await DeviceInfoPlugin().iosInfo).name;
  return Platform.localHostname;
}

String _cleanDeviceName(String rawName) {
  final cleaned = rawName.replaceAll(_controlCharacters, '').trim();
  if (cleaned.isEmpty) return 'Sharely device';
  const maxLength = ProtocolLimits.maxDeviceNameChars;
  return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
}

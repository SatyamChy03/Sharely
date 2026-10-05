import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// How this device introduces itself to the other side.
final localHelloProvider = FutureProvider<HelloMessage>((ref) async {
  final deviceId = await ref.read(trustStoreProvider).loadOrCreateDeviceId();
  return HelloMessage(
    deviceId: deviceId,
    deviceName: _cleanDeviceName(await _readDeviceName()),
    platform: currentDevicePlatform,
  );
});

Future<String> _readDeviceName() async {
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    return _androidDeviceName(info.manufacturer, info.model);
  }
  if (Platform.isIOS) return (await DeviceInfoPlugin().iosInfo).name;
  return Platform.localHostname;
}

// Android reports brands in lowercase ("motorola"), and some models repeat it.
String _androidDeviceName(String manufacturer, String model) {
  if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) return model;
  final brand = manufacturer[0].toUpperCase() + manufacturer.substring(1);
  return '$brand $model';
}

String _cleanDeviceName(String rawName) {
  final cleaned = rawName.replaceAll(_controlCharacters, '').trim();
  if (cleaned.isEmpty) return 'Sharely device';
  const maxLength = ProtocolLimits.maxDeviceNameChars;
  return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
}

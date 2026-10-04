import 'package:flutter/foundation.dart';
import 'package:sharely_core/sharely_core.dart';

/// The laptop role (server, shows QR) runs on desktop; phones scan.
bool get isDesktopRole => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS => true,
  _ => false,
};

DevicePlatform get currentDevicePlatform => switch (defaultTargetPlatform) {
  TargetPlatform.android => DevicePlatform.android,
  TargetPlatform.iOS => DevicePlatform.ios,
  TargetPlatform.windows => DevicePlatform.windows,
  TargetPlatform.macOS => DevicePlatform.macos,
  _ => DevicePlatform.linux,
};

String platformDisplayName(DevicePlatform platform) => switch (platform) {
  DevicePlatform.android => 'Android',
  DevicePlatform.ios => 'iPhone',
  DevicePlatform.windows => 'Windows',
  DevicePlatform.macos => 'Mac',
  DevicePlatform.linux => 'Linux',
};

part of 'protocol_message.dart';

enum DevicePlatform {
  android,
  ios,
  windows,
  macos,
  linux;

  /// Parses an untrusted platform name; null when it is not one we know.
  static DevicePlatform? fromWireName(String wireName) {
    for (final platform in values) {
      if (platform.name == wireName) return platform;
    }
    return null;
  }
}

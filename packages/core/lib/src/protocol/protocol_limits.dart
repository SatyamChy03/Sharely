/// Hard limits applied to every incoming message before it is trusted.
abstract final class ProtocolLimits {
  // 2: file checksums moved from the offer to the end of each upload.
  static const int protocolVersion = 2;

  static const int maxMessageChars = 256 * 1024;
  static const int maxFilesPerOffer = 1000;
  static const int maxFileNameChars = 1024;
  static const int maxFileSizeBytes = 1 << 40;
  static const int maxTransferBytes = 1 << 50;
  static const int maxMimeChars = 127;
  static const int maxDeviceNameChars = 64;
  static const int maxTextChars = 100000;
  static const int maxUrlChars = 2048;
  static const int minIdChars = 16;
  static const int maxIdChars = 64;
}

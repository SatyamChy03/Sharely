/// Sharely core: protocol, transfer engine, pairing, embedded server and
/// TLS pinning. Pure Dart, so it must not import Flutter.
library;

export 'src/pairing/lan_address.dart';
export 'src/pairing/paired_device.dart';
export 'src/pairing/pairing_client.dart';
export 'src/pairing/pairing_exception.dart';
export 'src/pairing/pairing_invite.dart';
export 'src/pairing/pairing_session.dart';
export 'src/protocol/message_codec.dart';
export 'src/protocol/protocol_exception.dart';
export 'src/protocol/protocol_ids.dart';
export 'src/protocol/protocol_limits.dart';
export 'src/protocol/protocol_message.dart';
export 'src/security/constant_time.dart';
export 'src/security/file_name_sanitizer.dart';
export 'src/security/file_safety_exception.dart';
export 'src/security/safe_file_creator.dart';
export 'src/security/secure_id.dart';
export 'src/server/pairing_request_handler.dart' show PairingRequestHandler;
export 'src/server/sharely_server.dart';

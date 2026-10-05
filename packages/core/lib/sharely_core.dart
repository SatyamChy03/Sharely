/// Sharely core: protocol, transfer engine, pairing, embedded server and
/// TLS pinning. Pure Dart, so it must not import Flutter.
library;

export 'src/pairing/device_endpoint.dart';
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
export 'src/server/control_hub.dart';
export 'src/server/pairing_request_handler.dart' show PairingRequestHandler;
export 'src/server/request_authenticator.dart' show PairedDeviceLookup;
export 'src/server/sharely_server.dart';
export 'src/server/transfer_receiver.dart';
export 'src/storage/memory_secret_store.dart';
export 'src/storage/paired_device_records.dart' show maxStoredPairedDevices;
export 'src/storage/secret_store.dart';
export 'src/storage/trust_store.dart';
export 'src/storage/trust_store_exception.dart';
export 'src/transfer/auth_headers.dart' show buildAuthHeaders;
export 'src/transfer/control_connection.dart';
export 'src/transfer/incoming_transfer_event.dart';
export 'src/transfer/mime_types.dart';
export 'src/transfer/outgoing_file.dart';
export 'src/transfer/outgoing_transfer.dart';
export 'src/transfer/outgoing_transfer_update.dart';
export 'src/transfer/transfer_exception.dart';

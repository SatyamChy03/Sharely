import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';

/// The group paired phones ask on. Its scope is one site and datagrams to
/// it travel a single hop, so a question never leaves the local network.
final InternetAddress discoveryMulticastGroup = InternetAddress(
  '239.255.83.72',
);

/// Discovery messages are tiny; anything larger is not one of ours.
const int maxDiscoveryDatagramBytes = 512;

/// Decodes an untrusted UDP datagram that must be a [expectedType] message.
JsonFields decodeDiscoveryDatagram(
  List<int> datagram, {
  required String expectedType,
}) {
  if (datagram.length > maxDiscoveryDatagramBytes) {
    throw const ProtocolException('Discovery datagram is too large');
  }
  final String text;
  try {
    text = utf8.decode(datagram);
  } on FormatException {
    throw const ProtocolException('Discovery datagram is not UTF-8');
  }
  final fields = JsonFields(decodeJsonObject(text));
  if (fields.string('type', maxLength: 16) != expectedType) {
    throw const ProtocolException('Unexpected discovery message type');
  }
  const version = ProtocolLimits.protocolVersion;
  if (fields.integer('v', min: version, max: version) != version) {
    throw const ProtocolException('Unsupported discovery version');
  }
  return fields;
}

List<int> encodeDiscoveryDatagram(String type, Map<String, Object> fields) {
  return utf8.encode(
    jsonEncode({'type': type, 'v': ProtocolLimits.protocolVersion, ...fields}),
  );
}

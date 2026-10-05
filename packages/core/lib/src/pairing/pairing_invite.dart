import 'dart:io';

import 'package:meta/meta.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_ids.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';

const _scheme = 'sharely';
const _action = 'pair';
const _formatVersion = '1';
const _maxInviteChars = 512;
const _queryKeys = {'v', 'h', 'p', 't', 'id', 'n'};
final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// What the laptop's QR code carries: where to connect and a one-time token.
///
/// Encoded as `sharely://pair?v=1&h=<ip>&p=<port>&t=<token>&id=<id>&n=<name>`.
@immutable
final class PairingInvite {
  const new({
    required this.host,
    required this.port,
    required this.token,
    required this.deviceId,
    required this.deviceName,
  });

  /// Parses scanned QR text. Throws [ProtocolException] unless it is a
  /// well-formed invite that points at a private LAN address.
  factory parse(String scannedText) {
    if (scannedText.length > _maxInviteChars) {
      throw const ProtocolException('QR code is too long');
    }
    final uri = Uri.tryParse(scannedText.trim());
    if (uri == null || uri.scheme != _scheme || uri.host != _action) {
      throw const ProtocolException('QR code is not a Sharely invite');
    }
    final query = uri.queryParameters;
    if (!_queryKeys.containsAll(query.keys) ||
        query.length != _queryKeys.length ||
        query['v'] != _formatVersion) {
      throw const ProtocolException('Invite has unexpected fields');
    }
    return PairingInvite(
      host: _parsePrivateHost(query['h']!),
      port: _parsePort(query['p']!),
      token: _parseId(query['t']!),
      deviceId: _parseId(query['id']!),
      deviceName: _parseDeviceName(query['n']!),
    );
  }

  final InternetAddress host;
  final int port;
  final String token;
  final String deviceId;
  final String deviceName;

  String toUriString() => Uri(
    scheme: _scheme,
    host: _action,
    queryParameters: {
      'v': _formatVersion,
      'h': host.address,
      'p': '$port',
      't': token,
      'id': deviceId,
      'n': deviceName,
    },
  ).toString();

  @override
  String toString() => 'PairingInvite(${host.address}:$port, $deviceName)';
}

InternetAddress _parsePrivateHost(String raw) {
  final address = InternetAddress.tryParse(raw);
  if (address == null || !isPrivateLanAddress(address)) {
    throw const ProtocolException('Invite host is not a private LAN address');
  }
  return address;
}

int _parsePort(String raw) {
  final port = int.tryParse(raw);
  if (port == null || port < 1024 || port > 65535) {
    throw const ProtocolException('Invite port is out of range');
  }
  return port;
}

String _parseId(String raw) {
  if (!isValidProtocolId(raw)) {
    throw const ProtocolException('Invite contains an invalid id');
  }
  return raw;
}

String _parseDeviceName(String raw) {
  if (raw.isEmpty ||
      raw.length > ProtocolLimits.maxDeviceNameChars ||
      _controlCharacters.hasMatch(raw)) {
    throw const ProtocolException('Invite device name is invalid');
  }
  return raw;
}

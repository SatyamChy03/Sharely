import 'package:meta/meta.dart';
import 'package:sharely_core/src/discovery/discovery_datagram.dart';

const _type = 'locate';

/// A paired phone asking, by broadcast, where its laptop is now.
@immutable
final class LocateQuery {
  const new({required this.fromDeviceId, required this.nonce});

  /// Throws a `ProtocolException` unless [datagram] is a valid query.
  factory decode(List<int> datagram) {
    final fields = decodeDiscoveryDatagram(datagram, expectedType: _type)
      ..requireOnlyKeys(const {'type', 'v', 'from', 'nonce'});
    return LocateQuery(
      fromDeviceId: fields.id('from'),
      nonce: fields.id('nonce'),
    );
  }

  final String fromDeviceId;

  /// Fresh per query, so an old reply cannot be replayed.
  final String nonce;

  List<int> encode() =>
      encodeDiscoveryDatagram(_type, {'from': fromDeviceId, 'nonce': nonce});
}

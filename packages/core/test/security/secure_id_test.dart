import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  test('ids are URL-safe and pass protocol id validation', () {
    final id = generateSecureId();
    expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
    final decoded = MessageCodec.decode('{"type":"accept","transferId":"$id"}');
    expect(decoded, isA<TransferDecisionMessage>());
  });

  test('ids do not repeat', () {
    final ids = {for (var i = 0; i < 1000; i++) generateSecureId()};
    expect(ids, hasLength(1000));
  });

  test('refuses fewer than 128 bits of entropy', () {
    expect(() => generateSecureId(byteLength: 8), throwsArgumentError);
  });
}

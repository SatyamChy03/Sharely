import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import '../support/test_tls.dart';

void main() {
  test('a new identity has a pinnable fingerprint and its own key', () {
    final other = TlsIdentity.generate();

    expect(isValidCertFingerprint(testIdentity.fingerprint), isTrue);
    expect(other.fingerprint, isNot(testIdentity.fingerprint));
    expect(other.privateKeyPem, isNot(testIdentity.privateKeyPem));
  });

  test('an identity read back from storage keeps its fingerprint', () {
    final restored = TlsIdentity.fromPem(
      certificatePem: testIdentity.certificatePem,
      privateKeyPem: testIdentity.privateKeyPem,
    );

    expect(restored.fingerprint, testIdentity.fingerprint);
  });

  test('the private key never appears in a description', () {
    final body = testIdentity.privateKeyPem.split('\n')[1];

    expect(testIdentity.toString(), isNot(contains(body)));
  });

  group('stored material is refused when', () {
    final other = TlsIdentity.generate();
    final unusable = {
      'the certificate is not PEM': (cert: 'hello', key: other.privateKeyPem),
      'the key is not PEM': (cert: other.certificatePem, key: 'hello'),
      'the key belongs to another certificate': (
        cert: other.certificatePem,
        key: testIdentity.privateKeyPem,
      ),
      'it is far too large': (cert: 'A' * 9000, key: other.privateKeyPem),
    };
    for (final MapEntry(key: description, value: stored) in unusable.entries) {
      test(description, () {
        expect(
          () => TlsIdentity.fromPem(
            certificatePem: stored.cert,
            privateKeyPem: stored.key,
          ),
          throwsA(isA<TlsIdentityException>()),
        );
      });
    }
  });

  group('the trust store', () {
    test('creates the identity once and serves the same one after', () async {
      final secrets = MemorySecretStore();

      final first = await TrustStore(secrets).loadOrCreateTlsIdentity();
      final second = await TrustStore(secrets).loadOrCreateTlsIdentity();

      expect(second.fingerprint, first.fingerprint);
    });

    test('replaces an identity it cannot use', () async {
      final secrets = MemorySecretStore();
      await secrets.write('sharely.tlsIdentity', '{"cert":"x","key":"y"}');

      final identity = await TrustStore(secrets).loadOrCreateTlsIdentity();
      final reloaded = await TrustStore(secrets).loadOrCreateTlsIdentity();

      expect(isValidCertFingerprint(identity.fingerprint), isTrue);
      expect(reloaded.fingerprint, identity.fingerprint);
    });
  });
}

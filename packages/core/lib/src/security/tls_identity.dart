import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:meta/meta.dart';
import 'package:sharely_core/src/security/cert_fingerprint.dart';

// Phones trust the fingerprint, not the dates, so the certificate only
// has to outlive the pairing.
const _validityDays = 3650;
const int _maxPemChars = 8 * 1024;
final _pemArmor = RegExp('-----[A-Z ]+-----');

/// Thrown when stored TLS material cannot be used to run a server.
class TlsIdentityException implements Exception {
  const new();

  @override
  String toString() => 'TlsIdentityException: unusable certificate or key';
}

/// The laptop's self-signed certificate and its private key.
///
/// The key never leaves the laptop; phones pin [fingerprint] at pairing.
@immutable
final class TlsIdentity {
  const new _(this.certificatePem, this.privateKeyPem, this.fingerprint);

  /// Creates a new P-256 key and a certificate signed with it.
  factory generate() {
    final keys = CryptoUtils.generateEcKeyPair();
    final privateKey = keys.privateKey as ECPrivateKey;
    final request = X509Utils.generateEccCsrPem(
      const {'CN': 'Sharely'},
      privateKey,
      keys.publicKey as ECPublicKey,
    );
    return TlsIdentity.fromPem(
      certificatePem: X509Utils.generateSelfSignedCertificate(
        privateKey,
        request,
        _validityDays,
      ),
      privateKeyPem: CryptoUtils.encodeEcPrivateKeyToPem(privateKey),
    );
  }

  /// Rebuilds an identity read from storage, which is validated like any
  /// other input. Throws [TlsIdentityException] when it cannot serve TLS.
  factory fromPem({
    required String certificatePem,
    required String privateKeyPem,
  }) {
    if (certificatePem.length > _maxPemChars ||
        privateKeyPem.length > _maxPemChars) {
      throw const TlsIdentityException();
    }
    final List<int> der;
    try {
      der = base64.decode(
        certificatePem.replaceAll(_pemArmor, '').replaceAll(RegExp(r'\s'), ''),
      );
    } on FormatException {
      throw const TlsIdentityException();
    }
    // Building a context proves the certificate and key parse and match.
    return TlsIdentity._(
      certificatePem,
      privateKeyPem,
      certificateFingerprint(der),
    )..createServerContext();
  }

  final String certificatePem;
  final String privateKeyPem;
  final String fingerprint;

  /// The context a server presents this identity with.
  SecurityContext createServerContext() {
    try {
      return SecurityContext()
        ..useCertificateChainBytes(utf8.encode(certificatePem))
        ..usePrivateKeyBytes(utf8.encode(privateKeyPem));
    } on TlsException {
      throw const TlsIdentityException();
      // dart:io reports text that is not PEM this way, not as an exception.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const TlsIdentityException();
    }
  }

  // The private key is deliberately left out so it never reaches a log.
  @override
  String toString() => 'TlsIdentity($fingerprint)';
}

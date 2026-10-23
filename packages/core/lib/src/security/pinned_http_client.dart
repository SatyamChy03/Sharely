import 'dart:io';

import 'package:sharely_core/src/security/cert_fingerprint.dart';
import 'package:sharely_core/src/security/constant_time.dart';

/// An HTTPS client that talks only to the server holding the certificate
/// with [certFingerprint].
///
/// The laptop's certificate is self-signed, so no authority vouches for
/// it; the fingerprint learnt at pairing is the whole check. The context
/// trusts no roots, so that check runs for every certificate. Any other
/// certificate fails the handshake before a token or a byte is sent.
HttpClient createPinnedHttpClient(
  String certFingerprint, {
  Duration connectionTimeout = const Duration(seconds: 8),
}) {
  return HttpClient(context: SecurityContext())
    ..connectionTimeout = connectionTimeout
    ..badCertificateCallback = (certificate, host, port) => constantTimeEquals(
      certificateFingerprint(certificate.der),
      certFingerprint,
    );
}

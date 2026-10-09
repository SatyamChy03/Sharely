import 'dart:convert';

import 'package:crypto/crypto.dart';

final _fingerprintPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// The SHA-256 of a DER certificate as 43 URL-safe characters.
///
/// This is what a phone pins: the laptop is whoever holds the key behind
/// the certificate with this fingerprint.
String certificateFingerprint(List<int> der) =>
    base64Url.encode(sha256.convert(der).bytes).replaceAll('=', '');

/// True when [value] has the shape [certificateFingerprint] produces.
bool isValidCertFingerprint(String value) =>
    _fingerprintPattern.hasMatch(value);

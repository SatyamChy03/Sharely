import 'package:sharely_core/sharely_core.dart';

/// One certificate for every loopback server in a test run.
final TlsIdentity testIdentity = TlsIdentity.generate();

/// A well-formed fingerprint that no test server presents.
final String unknownFingerprint = 'A' * 43;

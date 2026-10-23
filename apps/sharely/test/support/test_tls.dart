import 'package:sharely_core/sharely_core.dart';

/// One certificate for every loopback server in a test run.
final TlsIdentity testIdentity = TlsIdentity.generate();

/// A well-formed fingerprint for laptops no test connects to.
final String testFingerprint = 'A' * 43;

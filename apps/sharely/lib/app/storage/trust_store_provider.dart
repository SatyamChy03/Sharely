import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/app/storage/platform_secret_store.dart';
import 'package:sharely_core/sharely_core.dart';

/// Overridden in tests with an in-memory store.
final trustStoreProvider = Provider<TrustStore>(
  (ref) => const TrustStore(PlatformSecretStore()),
);

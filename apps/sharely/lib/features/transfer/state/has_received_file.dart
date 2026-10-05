import 'package:flutter_riverpod/flutter_riverpod.dart';

final hasReceivedFileProvider = NotifierProvider<HasReceivedFile, bool>(
  HasReceivedFile.new,
);

/// Whether a file has arrived this session; completes onboarding step 3.
class HasReceivedFile extends Notifier<bool> {
  @override
  bool build() => false;

  void markReceived() => state = true;
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sharely_core/sharely_core.dart';

const _saveFolderName = 'Sharely';

/// Where the laptop saves incoming files. Overridden in tests.
final saveDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => _defaultSaveDirectory,
);

Future<Directory> _defaultSaveDirectory() async {
  final base =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  return Directory('${base.path}${Platform.pathSeparator}$_saveFolderName');
}

/// The laptop's receiving side, alive as long as its server is.
final transferReceiverProvider = Provider<TransferReceiver>((ref) {
  final receiver = TransferReceiver(
    saveDirectory: ref.read(saveDirectoryProvider),
  );
  ref.onDispose(() => unawaited(receiver.close()));
  return receiver;
});

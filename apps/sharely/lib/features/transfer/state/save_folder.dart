import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';

/// The folder this laptop saves received files into.
final laptopSaveFolderProvider = FutureProvider<Directory>(
  (ref) => ref.watch(saveDirectoryProvider)(),
);

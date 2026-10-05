import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/app/sharely_app.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureLogging();
  final container = ProviderContainer();
  // Loaded before the first frame so a paired phone opens on Home.
  await container.read(pairedDevicesProvider.future);
  runApp(
    UncontrolledProviderScope(container: container, child: const SharelyApp()),
  );
}

void _configureLogging() {
  // Release builds keep only warnings; routine events stay out of device logs.
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}

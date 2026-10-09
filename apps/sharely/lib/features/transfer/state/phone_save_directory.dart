import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const _channel = MethodChannel('com.sharely/storage');
const _saveFolderName = 'Sharely';
final _log = Logger('PhoneSaveDirectory');

/// Where the phone saves files from the laptop. Overridden in tests.
final phoneSaveDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => _phoneSaveDirectory,
);

Future<Directory> _phoneSaveDirectory() async {
  final base =
      await _sharedDownloadsPath() ??
      (await getDownloadsDirectory())?.path ??
      (await getApplicationDocumentsDirectory()).path;
  return Directory('$base${Platform.pathSeparator}$_saveFolderName');
}

/// Android's shared Downloads folder, where the Files app can see the files;
/// null when this device won't let the app write there.
Future<String?> _sharedDownloadsPath() async {
  if (!Platform.isAndroid) return null;
  try {
    final downloads = await _channel.invokeMapMethod<String, Object?>(
      'sharedDownloads',
    );
    final path = downloads?['path'];
    if (path is! String) return null;
    // Android 10 and older guard the folder with a permission; newer
    // versions let an app add its own files without one.
    if (downloads?['needsPermission'] == true &&
        !(await Permission.storage.request()).isGranted) {
      return null;
    }
    return path;
  } on PlatformException catch (error) {
    _log.warning('Shared Downloads is unavailable: ${error.code}');
    return null;
  } on MissingPluginException {
    return null;
  }
}

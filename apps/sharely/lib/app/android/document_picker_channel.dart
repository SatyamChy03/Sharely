import 'package:flutter/services.dart';

const _channel = MethodChannel('com.sharely/document_picker');

/// A picked file the app reads through `fd`, which it must close when done.
typedef PickedDocument = ({String name, int sizeBytes, int fd});

/// Opens the Android picker; empty when the user backs out.
Future<List<PickedDocument>> pickAndroidDocuments({
  required bool mediaOnly,
}) async {
  final picked = await _channel.invokeListMethod<Object?>('pickFiles', {
    'mediaOnly': mediaOnly,
  });
  return [
    for (final item in picked ?? const <Object?>[])
      if (item
          case {
            'name': final String name,
            'size': final int sizeBytes,
            'fd': final int fd,
          }
          when sizeBytes >= 0 && fd >= 0)
        (name: name, sizeBytes: sizeBytes, fd: fd),
  ];
}

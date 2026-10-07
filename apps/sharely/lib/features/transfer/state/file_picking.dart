import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/app/android/document_picker_channel.dart';
import 'package:sharely/app/android/file_descriptor_reader.dart';
import 'package:sharely_core/sharely_core.dart';

/// The system file picker. Overridden in tests, which have no picker.
final sendFilePickerProvider = Provider<SendFilePicker>(
  (ref) => SendFilePicker(),
);

/// Picks files to send and lets go of them once the send is over.
class SendFilePicker {
  final _openDescriptors = <int>{};

  /// Empty when the user backs out of the picker.
  Future<List<OutgoingFile>> pickFiles({bool photosOnly = false}) =>
      Platform.isAndroid
      ? _pickOnAndroid(photosOnly: photosOnly)
      : _pickWithFilePicker(photosOnly: photosOnly);

  /// Closes what the last pick opened; call once its send has finished.
  Future<void> releasePickedFiles() async {
    _openDescriptors
      ..forEach(closeFileDescriptor)
      ..clear();
    // Only the iOS picker leaves copies behind; elsewhere this is unsupported.
    if (Platform.isIOS) await FilePicker.clearTemporaryFiles();
  }

  // Reads the originals directly: the generic picker would first copy each
  // file into the cache, which for a large video takes minutes.
  Future<List<OutgoingFile>> _pickOnAndroid({required bool photosOnly}) async {
    final documents = await pickAndroidDocuments(mediaOnly: photosOnly);
    _openDescriptors.addAll(documents.map((document) => document.fd));
    return [
      for (final document in documents)
        OutgoingFile(
          name: document.name,
          sizeBytes: document.sizeBytes,
          mimeType: guessMimeType(document.name),
          openRead: () => readFileDescriptor(document.fd),
        ),
    ];
  }

  Future<List<OutgoingFile>> _pickWithFilePicker({
    required bool photosOnly,
  }) async {
    final picked = await FilePicker.pickFiles(
      type: photosOnly ? FileType.media : FileType.any,
    );
    return await Future.wait(
      picked.map((file) async {
        final source = file.xFile;
        return OutgoingFile(
          name: file.name,
          sizeBytes: await source.length(),
          mimeType: guessMimeType(file.name),
          openRead: source.openRead,
        );
      }),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely_core/sharely_core.dart';

/// The system file picker. Overridden in tests, which have no picker.
final sendFilePickerProvider = Provider<SendFilePicker>(
  (ref) => const SendFilePicker(),
);

/// Picks files to send and cleans up the copies some pickers make.
class SendFilePicker {
  const new();

  /// Empty when the user backs out of the picker.
  Future<List<OutgoingFile>> pickFiles() async {
    final picked = await FilePicker.pickFiles();
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

  /// Removes picker cache copies once a send has finished with them.
  Future<void> clearPickedCopies() => FilePicker.clearTemporaryFiles();
}

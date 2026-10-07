import 'dart:async';

import 'package:sharely/app/android/background_transfer.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely_core/sharely_core.dart';

// Android throttles apps that update a notification many times a second.
const _updateInterval = Duration(seconds: 1);

/// Mirrors one send into the system notification while it runs.
class BackgroundSendNotice {
  new(
    this._background, {
    required this.laptopName,
    required this.fileCount,
    required this.totalBytes,
  });

  final BackgroundTransfer _background;
  final String laptopName;
  final int fileCount;
  final int totalBytes;
  final _sinceLastUpdate = Stopwatch();

  String get _sendingTitle =>
      'Sending ${formatFileCount(fileCount)} to $laptopName';

  Future<void> start({required void Function() onCancelRequested}) =>
      _background.start(
        title: _sendingTitle,
        text: formatByteCount(totalBytes),
        onCancelRequested: onCancelRequested,
      );

  void showProgress({required int bytesSent, required double bytesPerSecond}) {
    if (_sinceLastUpdate.isRunning &&
        _sinceLastUpdate.elapsed < _updateInterval) {
      return;
    }
    _sinceLastUpdate
      ..reset()
      ..start();
    final percent = totalBytes == 0 ? 100 : bytesSent * 100 ~/ totalBytes;
    unawaited(
      _background.update(
        title: _sendingTitle,
        text:
            '$percent% · ${formatByteCount(bytesSent)} of '
            '${formatByteCount(totalBytes)} · ${formatSpeed(bytesPerSecond)}',
        percent: percent,
      ),
    );
  }

  /// [failure] is null when every file arrived.
  Future<void> end(TransferFailure? failure) {
    if (failure == null) {
      return _background.finish(
        title: 'Sent to $laptopName',
        text: '${formatFileCount(fileCount)} · ${formatByteCount(totalBytes)}',
      );
    }
    // The user cancelled, so a notification about it would only be noise.
    if (failure == TransferFailure.cancelled) return _background.stop();
    return _background.finish(
      title: "Send to $laptopName didn't finish",
      text: describeSendFailure(failure),
    );
  }
}

import 'dart:async';

import 'package:sharely/app/android/background_transfer.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely_core/sharely_core.dart';

// Android throttles apps that update a notification many times a second.
const _updateInterval = Duration(seconds: 1);

/// Mirrors one download into the system notification while it runs.
class BackgroundReceiveNotice {
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
  int _lastPercent = 0;

  String get _receivingTitle =>
      'Receiving ${formatFileCount(fileCount)} from $laptopName';

  Future<void> start({required void Function() onCancelRequested}) =>
      _background.start(
        title: _receivingTitle,
        text: formatByteCount(totalBytes),
        onCancelRequested: onCancelRequested,
      );

  void showProgress({
    required int bytesReceived,
    required double bytesPerSecond,
  }) {
    if (_sinceLastUpdate.isRunning &&
        _sinceLastUpdate.elapsed < _updateInterval) {
      return;
    }
    _sinceLastUpdate
      ..reset()
      ..start();
    final percent = totalBytes == 0 ? 100 : bytesReceived * 100 ~/ totalBytes;
    _lastPercent = percent;
    unawaited(
      _background.update(
        title: _receivingTitle,
        text:
            '$percent% · ${formatByteCount(bytesReceived)} of '
            '${formatByteCount(totalBytes)} · ${formatSpeed(bytesPerSecond)}',
        percent: percent,
      ),
    );
  }

  /// Says the download is waiting for the connection, not stuck or lost.
  void showReconnecting() {
    _sinceLastUpdate.reset();
    unawaited(
      _background.update(
        title: 'Reconnecting to $laptopName…',
        text: 'The download continues by itself when the Wi-Fi is back.',
        percent: _lastPercent,
      ),
    );
  }

  /// [failure] is null when every file was saved.
  Future<void> end(TransferFailure? failure) {
    if (failure == null) {
      return _background.finish(
        title: 'Saved ${formatFileCount(fileCount)} from $laptopName',
        text: 'In Downloads/Sharely · ${formatByteCount(totalBytes)}',
      );
    }
    // A cancel is already known to whoever pressed it; don't add noise.
    if (failure == TransferFailure.cancelled) return _background.stop();
    return _background.finish(
      title: "Files from $laptopName didn't finish",
      text: describeReceiveFailure(failure, laptopName),
    );
  }
}

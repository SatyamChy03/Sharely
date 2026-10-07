import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/app/android/background_transfer.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/transfer/state/background_send_notice.dart';
import 'package:sharely/features/transfer/state/file_picking.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely_core/sharely_core.dart';

final _log = Logger('Send');

// Smooths the speed readout so it doesn't jitter between progress reports.
const _speedSmoothing = 0.3;

final sendProvider = NotifierProvider<SendController, SendState>(
  SendController.new,
);

/// Phone side: pick files, offer them to the laptop and track the send.
class SendController extends Notifier<SendState> {
  OutgoingTransfer? _transfer;
  final _sinceLastProgress = Stopwatch();
  int _lastBytesSent = 0;
  double _bytesPerSecond = 0;

  @override
  SendState build() {
    ref.onDispose(() => _transfer?.cancel());
    return const SendIdle();
  }

  /// Returns false when the user picked nothing or the laptop isn't connected.
  Future<bool> pickAndSend({bool photosOnly = false}) async {
    if (state is! SendIdle) return false;
    final picker = ref.read(sendFilePickerProvider);
    final files = await picker.pickFiles(photosOnly: photosOnly);
    if (files.isEmpty || !ref.mounted) return false;
    final connection = ref.read(laptopConnectionProvider);
    final endpoint = connection is LaptopConnected
        ? connection.laptop.endpoint
        : null;
    if (connection is! LaptopConnected || endpoint == null) {
      await picker.releasePickedFiles();
      return false;
    }
    final localHello = await ref.read(localHelloProvider.future);
    final transfer = OutgoingTransfer.start(
      files: files,
      connection: connection.connection,
      endpoint: endpoint,
      authHeaders: buildAuthHeaders(
        localDeviceId: localHello.deviceId,
        authToken: connection.laptop.authToken,
      ),
    );
    final notice = BackgroundSendNotice(
      ref.read(backgroundTransferProvider),
      laptopName: connection.laptop.deviceName,
      fileCount: files.length,
      totalBytes: transfer.totalBytes,
    );
    unawaited(notice.start(onCancelRequested: cancel));
    _track(transfer, notice);
    unawaited(_finish(transfer, notice, picker));
    return true;
  }

  void cancel() => _transfer?.cancel();

  /// Clears a finished send so the next one can start.
  void dismiss() {
    if (state is SendWithFiles && _transfer == null) state = const SendIdle();
  }

  void _track(OutgoingTransfer transfer, BackgroundSendNotice notice) {
    _transfer = transfer;
    _lastBytesSent = 0;
    _bytesPerSecond = 0;
    final files = List<SendFileInfo>.unmodifiable([
      for (final file in transfer.files)
        (name: file.name, sizeBytes: file.sizeBytes),
    ]);
    state = SendPreparing(files: files);
    transfer.updates.listen((update) {
      if (!ref.mounted) return;
      state = switch (update) {
        OutgoingTransferAwaitingAcceptance() => SendAwaitingAcceptance(
          files: files,
        ),
        OutgoingTransferSending(:final bytesSent) => _showProgress(
          files,
          bytesSent,
          notice,
        ),
        OutgoingTransferCompleted() => _succeed(files),
        OutgoingTransferFailed(:final reason) => SendFailed(
          files: files,
          reason: reason,
        ),
      };
    });
  }

  SendInProgress _showProgress(
    List<SendFileInfo> files,
    int bytesSent,
    BackgroundSendNotice notice,
  ) {
    final bytesPerSecond = _measureSpeed(bytesSent);
    notice.showProgress(bytesSent: bytesSent, bytesPerSecond: bytesPerSecond);
    return SendInProgress(
      files: files,
      bytesSent: bytesSent,
      bytesPerSecond: bytesPerSecond,
    );
  }

  Future<void> _finish(
    OutgoingTransfer transfer,
    BackgroundSendNotice notice,
    SendFilePicker picker,
  ) async {
    TransferFailure? failure;
    try {
      await transfer.done;
    } on TransferException catch (error) {
      failure = error.failure;
      _log.info('Send ended: ${failure.name}');
    }
    _transfer = null;
    await notice.end(failure);
    await picker.releasePickedFiles();
  }

  SendSucceeded _succeed(List<SendFileInfo> files) {
    final now = DateTime.now();
    ref.read(recentTransfersProvider.notifier).record([
      for (final file in files)
        RecentTransfer(
          name: file.name,
          sizeBytes: file.sizeBytes,
          direction: TransferDirection.sent,
          finishedAt: now,
        ),
    ]);
    return SendSucceeded(files: files);
  }

  double _measureSpeed(int bytesSent) {
    final seconds = _sinceLastProgress.elapsedMicroseconds / 1e6;
    if (_sinceLastProgress.isRunning && seconds > 0) {
      final instant = (bytesSent - _lastBytesSent) / seconds;
      _bytesPerSecond = _bytesPerSecond == 0
          ? instant
          : _bytesPerSecond + _speedSmoothing * (instant - _bytesPerSecond);
    }
    _lastBytesSent = bytesSent;
    _sinceLastProgress
      ..reset()
      ..start();
    return _bytesPerSecond;
  }
}

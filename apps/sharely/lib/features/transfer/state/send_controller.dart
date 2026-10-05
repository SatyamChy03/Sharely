import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/transfer/state/file_picking.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
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
  Future<bool> pickAndSend() async {
    if (state is! SendIdle) return false;
    final files = await ref.read(sendFilePickerProvider).pickFiles();
    final connection = ref.read(laptopConnectionProvider);
    if (files.isEmpty || connection is! LaptopConnected || !ref.mounted) {
      return false;
    }
    final endpoint = connection.laptop.endpoint;
    if (endpoint == null) return false;
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
    _track(transfer);
    return true;
  }

  void cancel() => _transfer?.cancel();

  /// Clears a finished send so the next one can start.
  void dismiss() {
    if (state is SendWithFiles && _transfer == null) state = const SendIdle();
  }

  void _track(OutgoingTransfer transfer) {
    _transfer = transfer;
    _lastBytesSent = 0;
    _bytesPerSecond = 0;
    final fileCount = transfer.files.length;
    final totalBytes = transfer.totalBytes;
    state = SendPreparing(fileCount: fileCount, totalBytes: totalBytes);
    transfer.updates.listen((update) {
      if (!ref.mounted) return;
      state = switch (update) {
        OutgoingTransferPreparing() => state,
        OutgoingTransferAwaitingAcceptance() => SendAwaitingAcceptance(
          fileCount: fileCount,
          totalBytes: totalBytes,
        ),
        OutgoingTransferSending(:final bytesSent) => SendInProgress(
          fileCount: fileCount,
          totalBytes: totalBytes,
          bytesSent: bytesSent,
          bytesPerSecond: _measureSpeed(bytesSent),
        ),
        OutgoingTransferCompleted() => SendSucceeded(
          fileCount: fileCount,
          totalBytes: totalBytes,
        ),
        OutgoingTransferFailed(:final reason) => SendFailed(
          fileCount: fileCount,
          totalBytes: totalBytes,
          reason: reason,
        ),
      };
    });
    unawaited(_finish(transfer));
  }

  Future<void> _finish(OutgoingTransfer transfer) async {
    try {
      await transfer.done;
    } on TransferException catch (error) {
      _log.info('Send ended: ${error.failure.name}');
    }
    _transfer = null;
    if (!ref.mounted) return;
    await ref.read(sendFilePickerProvider).clearPickedCopies();
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

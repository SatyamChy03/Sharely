import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/app/android/background_transfer.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/transfer/state/background_send_notice.dart';
import 'package:sharely/features/transfer/state/file_picking.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/laptop_reconnect.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/state/speed_meter.dart';
import 'package:sharely_core/sharely_core.dart';

final _log = Logger('Send');

final sendProvider = NotifierProvider<SendController, SendState>(
  SendController.new,
);

/// Phone side: pick files, offer them to the laptop and track the send.
class SendController extends Notifier<SendState> {
  OutgoingTransfer? _transfer;
  final _speed = SpeedMeter();

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
      reconnect: ref.read(laptopReconnectProvider),
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

  /// Sends a note, an OTP or a link straight to the laptop's screen.
  QuickTextResult sendText(String raw) {
    if (raw.trim().isEmpty) return QuickTextResult.empty;
    final ProtocolMessage message;
    try {
      message = composeQuickText(raw);
    } on ProtocolException {
      return QuickTextResult.tooLong;
    }
    final connection = ref.read(laptopConnectionProvider);
    if (connection is! LaptopConnected || !connection.connection.isOpen) {
      return QuickTextResult.notConnected;
    }
    connection.connection.send(message);
    return QuickTextResult.sent;
  }

  void cancel() => _transfer?.cancel();

  /// Clears a finished send so the next one can start.
  void dismiss() {
    if (state is SendWithFiles && _transfer == null) state = const SendIdle();
  }

  void _track(OutgoingTransfer transfer, BackgroundSendNotice notice) {
    _transfer = transfer;
    _speed.reset();
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
        OutgoingTransferReconnecting() => _showReconnecting(files, notice),
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
    final bytesPerSecond = _speed.measure(bytesSent);
    notice.showProgress(bytesSent: bytesSent, bytesPerSecond: bytesPerSecond);
    return SendInProgress(
      files: files,
      bytesSent: bytesSent,
      bytesPerSecond: bytesPerSecond,
    );
  }

  SendInProgress _showReconnecting(
    List<SendFileInfo> files,
    BackgroundSendNotice notice,
  ) {
    final current = state;
    final bytesSent = current is SendInProgress ? current.bytesSent : 0;
    // The speed before the drop says nothing about the speed after it.
    _speed.reset();
    notice.showReconnecting(bytesSent: bytesSent);
    return SendInProgress(
      files: files,
      bytesSent: bytesSent,
      bytesPerSecond: 0,
      isReconnecting: true,
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
}

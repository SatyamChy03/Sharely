import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/file_picking.dart';
import 'package:sharely/features/transfer/state/outgoing_file_collector.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/state/speed_meter.dart';
import 'package:sharely/features/transfer/state/transfer_sender_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final phoneSendProvider = NotifierProvider<PhoneSendController, SendState>(
  PhoneSendController.new,
);

/// Laptop side: offer files or text to the paired phone and track the send.
class PhoneSendController extends Notifier<SendState> {
  String? _transferId;
  List<SendFileInfo> _files = const [];
  final _speed = SpeedMeter();

  TransferSender get _sender => ref.read(transferSenderProvider);

  PairedDevice? get _phone =>
      (ref.read(pairedDevicesProvider).value ?? const []).lastOrNull;

  @override
  SendState build() {
    final subscription = ref
        .watch(transferSenderProvider)
        .events
        .listen(_applyEvent);
    ref.onDispose(subscription.cancel);
    return const SendIdle();
  }

  Future<void> pickAndSendFiles() async {
    if (state is! SendIdle) return;
    final files = await ref.read(sendFilePickerProvider).pickFiles();
    if (files.isEmpty || !ref.mounted) return;
    _offer(files);
  }

  Future<void> pickAndSendFolder() async {
    if (state is! SendIdle) return;
    final folder = await ref.read(folderPickerProvider)();
    if (folder == null || !ref.mounted) return;
    await sendPaths([folder]);
  }

  /// Sends dropped or chosen [paths]; folders send the files inside them.
  Future<void> sendPaths(List<String> paths) async {
    if (state is! SendIdle || paths.isEmpty) return;
    final List<OutgoingFile> files;
    try {
      files = await collectOutgoingFiles(paths);
    } on FileSystemException {
      if (!ref.mounted) return;
      state = const SendFailed(
        files: [],
        reason: TransferFailure.unreadableFile,
      );
      return;
    }
    if (!ref.mounted || state is! SendIdle) return;
    if (files.isEmpty) {
      state = const SendFailed(files: [], reason: TransferFailure.noFiles);
      return;
    }
    _offer(files);
  }

  /// Sends a note, an OTP or a link straight to the phone's screen.
  QuickTextResult sendText(String raw) {
    if (raw.trim().isEmpty) return QuickTextResult.empty;
    final phone = _phone;
    final ProtocolMessage message;
    try {
      message = composeQuickText(raw);
    } on ProtocolException {
      return QuickTextResult.tooLong;
    }
    if (phone == null || !_sender.hub.send(phone.deviceId, message)) {
      return QuickTextResult.notConnected;
    }
    return QuickTextResult.sent;
  }

  void cancel() {
    final transferId = _transferId;
    if (transferId != null) _sender.cancel(transferId);
  }

  /// Clears a finished send so the next one can start.
  void dismiss() {
    if (state is SendWithFiles && _transferId == null) state = const SendIdle();
  }

  void _offer(List<OutgoingFile> files) {
    final infos = List<SendFileInfo>.unmodifiable([
      for (final file in files) (name: file.name, sizeBytes: file.sizeBytes),
    ]);
    final phone = _phone;
    try {
      if (phone == null) {
        throw const TransferException(TransferFailure.unreachable);
      }
      _transferId = _sender.offerFiles(deviceId: phone.deviceId, files: files);
    } on TransferException catch (error) {
      state = SendFailed(files: infos, reason: error.failure);
      return;
    }
    _files = infos;
    _speed.reset();
    state = SendAwaitingAcceptance(files: infos);
  }

  void _applyEvent(SentTransferEvent event) {
    if (event.transferId != _transferId) return;
    switch (event.update) {
      case OutgoingTransferAwaitingAcceptance():
        break;
      case OutgoingTransferSending(:final bytesSent):
        state = SendInProgress(
          files: _files,
          bytesSent: bytesSent,
          bytesPerSecond: _speed.measure(bytesSent),
        );
      case OutgoingTransferReconnecting():
        final current = state;
        _speed.reset();
        state = SendInProgress(
          files: _files,
          bytesSent: current is SendInProgress ? current.bytesSent : 0,
          bytesPerSecond: 0,
          isReconnecting: true,
        );
      case OutgoingTransferCompleted():
        _transferId = null;
        _recordSent();
        state = SendSucceeded(files: _files);
      case OutgoingTransferFailed(:final reason):
        _transferId = null;
        state = SendFailed(files: _files, reason: reason);
    }
  }

  void _recordSent() {
    final now = DateTime.now();
    ref.read(recentTransfersProvider.notifier).record([
      for (final file in _files)
        RecentTransfer(
          name: file.name,
          sizeBytes: file.sizeBytes,
          direction: TransferDirection.sent,
          finishedAt: now,
        ),
    ]);
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final incomingTransfersProvider =
    NotifierProvider<IncomingTransfersController, List<IncomingTransferView>>(
      IncomingTransfersController.new,
    );

/// Laptop side: incoming offers and their progress, newest last.
class IncomingTransfersController extends Notifier<List<IncomingTransferView>> {
  /// Long enough to read "Saved"; the file stays listed under Activity.
  static const savedNoticeDuration = Duration(seconds: 6);

  final _dismissTimers = <Timer>[];

  TransferReceiver get _receiver => ref.read(transferReceiverProvider);

  @override
  List<IncomingTransferView> build() {
    final subscription = ref
        .watch(transferReceiverProvider)
        .events
        .listen(_applyEvent);
    ref
      ..onDispose(subscription.cancel)
      ..onDispose(_cancelDismissTimers);
    return const [];
  }

  /// [alwaysFromSender] skips the prompt for this sender from now on.
  void accept(String transferId, {bool alwaysFromSender = false}) {
    if (alwaysFromSender) {
      final view = state.where((view) => view.transferId == transferId);
      for (final match in view) {
        unawaited(
          ref
              .read(pairedDevicesProvider.notifier)
              .setAlwaysAccept(match.senderId, isOn: true),
        );
      }
    }
    _receiver.accept(transferId);
    _update(
      transferId,
      (view) => view.copyWith(stage: IncomingTransferStage.receiving),
    );
  }

  void decline(String transferId) {
    _receiver.reject(transferId);
    dismiss(transferId);
  }

  void cancel(String transferId) => _receiver.cancel(transferId);

  void dismiss(String transferId) {
    state = [
      for (final view in state)
        if (view.transferId != transferId) view,
    ];
  }

  void _applyEvent(IncomingTransferEvent event) {
    switch (event) {
      case IncomingOfferReceived(:final sender, :final offer):
        state = [
          ...state,
          IncomingTransferView(
            transferId: offer.transferId,
            senderId: sender.deviceId,
            senderName: sender.deviceName,
            fileNames: [for (final file in offer.files) file.name],
            fileSizes: [for (final file in offer.files) file.sizeBytes],
            totalBytes: offer.totalBytes,
          ),
        ];
        if (sender.alwaysAccept && canAcceptWithoutAsking(offer)) {
          accept(offer.transferId);
        }
      case IncomingTransferProgressed(:final transferId, :final bytesReceived):
        _update(
          transferId,
          (view) => view.copyWith(
            bytesReceived: bytesReceived,
            isReconnecting: false,
          ),
        );
      case IncomingTransferInterrupted(:final transferId):
        _update(transferId, (view) => view.copyWith(isReconnecting: true));
      case IncomingTransferCompleted(:final transferId, :final savedFiles):
        _recordReceived(transferId, savedFiles);
        _update(
          transferId,
          (view) => view.copyWith(
            stage: IncomingTransferStage.saved,
            bytesReceived: view.totalBytes,
            savedFiles: savedFiles,
          ),
        );
        _dismissTimers.add(
          Timer(savedNoticeDuration, () => dismiss(transferId)),
        );
      case IncomingTransferEnded(:final transferId, :final reason):
        _update(
          transferId,
          (view) => view.copyWith(
            stage: IncomingTransferStage.failed,
            failure: reason,
          ),
        );
    }
  }

  void _cancelDismissTimers() {
    for (final timer in _dismissTimers) {
      timer.cancel();
    }
    _dismissTimers.clear();
  }

  void _recordReceived(String transferId, List<File> savedFiles) {
    final view = state.where((view) => view.transferId == transferId);
    if (view.isEmpty) return;
    final sizes = view.first.fileSizes;
    final now = DateTime.now();
    ref.read(recentTransfersProvider.notifier).record([
      // Files are uploaded in offer order, so sizes line up by index.
      for (final (index, file) in savedFiles.indexed)
        RecentTransfer(
          name: file.uri.pathSegments.last,
          sizeBytes: index < sizes.length ? sizes[index] : 0,
          direction: TransferDirection.received,
          finishedAt: now,
          savedFile: file,
        ),
    ]);
  }

  void _update(
    String transferId,
    IncomingTransferView Function(IncomingTransferView view) change,
  ) {
    state = [
      for (final view in state)
        if (view.transferId == transferId) change(view) else view,
    ];
  }
}

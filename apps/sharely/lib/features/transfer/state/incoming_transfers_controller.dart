import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/has_received_file.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final incomingTransfersProvider =
    NotifierProvider<IncomingTransfersController, List<IncomingTransferView>>(
      IncomingTransfersController.new,
    );

/// Laptop side: incoming offers and their progress, newest last.
class IncomingTransfersController extends Notifier<List<IncomingTransferView>> {
  TransferReceiver get _receiver => ref.read(transferReceiverProvider);

  @override
  List<IncomingTransferView> build() {
    final subscription = ref
        .watch(transferReceiverProvider)
        .events
        .listen(_applyEvent);
    ref.onDispose(subscription.cancel);
    return const [];
  }

  void accept(String transferId) {
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
            senderName: sender.deviceName,
            fileNames: [for (final file in offer.files) file.name],
            totalBytes: offer.totalBytes,
          ),
        ];
      case IncomingTransferProgressed(:final transferId, :final bytesReceived):
        _update(
          transferId,
          (view) => view.copyWith(bytesReceived: bytesReceived),
        );
      case IncomingTransferCompleted(:final transferId, :final savedFiles):
        ref.read(hasReceivedFileProvider.notifier).markReceived();
        _update(
          transferId,
          (view) => view.copyWith(
            stage: IncomingTransferStage.saved,
            bytesReceived: view.totalBytes,
            savedFiles: savedFiles,
          ),
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

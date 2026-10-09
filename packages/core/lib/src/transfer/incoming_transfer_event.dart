import 'dart:io';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';

/// What the receiving UI hears about incoming transfers.
sealed class IncomingTransferEvent {
  const new(this.transferId);

  final String transferId;
}

/// A paired device wants to send files; accept or reject it.
final class IncomingOfferReceived extends IncomingTransferEvent {
  new({required this.sender, required this.offer}) : super(offer.transferId);

  final PairedDevice sender;
  final OfferMessage offer;
}

final class IncomingTransferProgressed extends IncomingTransferEvent {
  const new(
    super.transferId, {
    required this.bytesReceived,
    required this.totalBytes,
  });

  final int bytesReceived;
  final int totalBytes;
}

/// The connection dropped mid-transfer; it resumes by itself if the other
/// device comes back in time. The next progress event means it has.
final class IncomingTransferInterrupted extends IncomingTransferEvent {
  const new(super.transferId);
}

/// Every file arrived and matched its checksum.
final class IncomingTransferCompleted extends IncomingTransferEvent {
  const new(super.transferId, {required this.savedFiles});

  final List<File> savedFiles;
}

/// Stopped early; files already verified stay saved.
final class IncomingTransferEnded extends IncomingTransferEvent {
  const new(super.transferId, {required this.reason});

  final TransferFailure reason;
}

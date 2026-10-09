import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/file_safety_exception.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/transfer/guarded_stream.dart';
import 'package:sharely_core/src/transfer/incoming_file_writer.dart';
import 'package:sharely_core/src/transfer/incoming_transfer.dart';
import 'package:sharely_core/src/transfer/parallel_settings.dart';
import 'package:sharely_core/src/transfer/resume_settings.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// The HTTP half of receiving: writes the files of accepted transfers to
/// disk and tells a returning phone where to continue. Internal to the
/// receiver, which owns the transfers and decides what each outcome means.
class UploadIntake {
  new({
    required this.findTransfer,
    required this.saveDirectory,
    required this.dataIdleTimeout,
    required this.onBytesWritten,
    required this.onInterrupted,
    required this.onIdle,
    required this.onAllFilesSaved,
    required this.onFailed,
  });

  final IncomingTransfer? Function(String transferId) findTransfer;
  final Future<Directory> Function() saveDirectory;
  final Duration dataIdleTimeout;
  final void Function(IncomingTransfer transfer, int byteCount) onBytesWritten;

  /// An upload broke off; its bytes are kept for a resume.
  final void Function(IncomingTransfer transfer) onInterrupted;

  /// No upload is in flight any more.
  final void Function(IncomingTransfer transfer) onIdle;
  final void Function(IncomingTransfer transfer) onAllFilesSaved;
  final void Function(IncomingTransfer transfer, TransferFailure reason)
  onFailed;

  /// `PUT /v1/transfers/<transferId>/<fileIndex>`.
  ///
  /// The [resumeOffsetHeader] says where the body starts; it must match the
  /// bytes already held, which the phone learns from [handleOffset].
  Future<Response> handleUpload(Request request) async {
    final target = _findReceivingFile(request);
    if (target == null) return Response.notFound(null);
    final (:transfer, :fileIndex) = target;
    final offset = int.tryParse(request.headers[resumeOffsetHeader] ?? '0');
    await transfer.settleUpload(fileIndex);
    final bytesHeld = transfer.partials[fileIndex]?.bytesWritten ?? 0;
    if (transfer.activeUploads.length >= maxParallelFilesPerTransfer) {
      return Response(HttpStatus.serviceUnavailable);
    }
    if (transfer.isEnded ||
        transfer.savedFilesByIndex.containsKey(fileIndex) ||
        transfer.activeUploads.containsKey(fileIndex) ||
        offset != bytesHeld) {
      return Response(HttpStatus.conflict);
    }
    final expected = transfer.offer.files[fileIndex];
    final declaredLength = request.contentLength;
    if (declaredLength != null &&
        declaredLength !=
            expected.sizeBytes - bytesHeld + uploadChecksumBytes) {
      onFailed(transfer, TransferFailure.corrupted);
      return Response.badRequest();
    }
    return await _receiveFile(transfer, fileIndex, request.read());
  }

  /// `GET /v1/transfers/<transferId>/<fileIndex>/offset`: how much of the
  /// file is already here, so a resumed upload sends only the rest.
  Future<Response> handleOffset(Request request) async {
    final target = _findReceivingFile(request);
    if (target == null) return Response.notFound(null);
    final (:transfer, :fileIndex) = target;
    // A half-dead upload must let go first, or the answer could go stale.
    await transfer.settleUpload(fileIndex);
    if (transfer.isEnded) return Response.notFound(null);
    final isSaved = transfer.savedFilesByIndex.containsKey(fileIndex);
    final bytesHeld = isSaved
        ? transfer.offer.files[fileIndex].sizeBytes
        : transfer.partials[fileIndex]?.bytesWritten ?? 0;
    return Response.ok(
      jsonEncode({'bytes': bytesHeld, 'saved': isSaved}),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
    );
  }

  /// The accepted transfer and file a request names, if the caller owns it.
  ({IncomingTransfer transfer, int fileIndex})? _findReceivingFile(
    Request request,
  ) {
    final transfer = findTransfer(request.params['transferId'] ?? '');
    final fileIndex = int.tryParse(request.params['fileIndex'] ?? '') ?? -1;
    // Unknown, foreign and out-of-range requests all look the same.
    if (transfer == null ||
        !transfer.isFrom(authenticatedDevice(request)) ||
        transfer.stage != IncomingTransferStage.receiving ||
        fileIndex < 0 ||
        fileIndex >= transfer.offer.files.length) {
      return null;
    }
    return (transfer: transfer, fileIndex: fileIndex);
  }

  Future<Response> _receiveFile(
    IncomingTransfer transfer,
    int fileIndex,
    Stream<List<int>> body,
  ) async {
    final upload = (interrupt: Completer<void>(), settled: Completer<void>());
    transfer.activeUploads[fileIndex] = upload;
    transfer.stallTimer?.cancel();
    try {
      final partial = transfer.partials[fileIndex] ??= await _createPartial(
        transfer.offer.files[fileIndex],
      );
      await partial.append(
        guardStream(
          body,
          interrupted: upload.interrupt.future,
          idleTimeout: dataIdleTimeout,
        ),
        isCancelled: () => transfer.isEnded,
        onBytesWritten: (byteCount) => onBytesWritten(transfer, byteCount),
      );
      // A cancel can land while the file is being closed; it must still win.
      if (transfer.isEnded) {
        await partial.discard();
        return Response(HttpStatus.conflict);
      }
      transfer.partials.remove(fileIndex);
      transfer.savedFilesByIndex[fileIndex] = partial.file;
    } on TransferInterrupted {
      return await _pauseAfterBrokenUpload(transfer, fileIndex);
    } on TransferException catch (error) {
      onFailed(transfer, error.failure);
      return error.failure == TransferFailure.corrupted
          ? Response(HttpStatus.unprocessableEntity)
          : Response(HttpStatus.conflict);
    } on IOException {
      onFailed(transfer, TransferFailure.refused);
      return Response(HttpStatus.conflict);
    } on FileSafetyException {
      onFailed(transfer, TransferFailure.refused);
      return Response(HttpStatus.conflict);
    } finally {
      transfer.activeUploads.remove(fileIndex);
      upload.settled.complete();
      if (transfer.activeUploads.isEmpty) onIdle(transfer);
    }
    if (transfer.hasAllFiles) onAllFilesSaved(transfer);
    return Response(HttpStatus.noContent);
  }

  Future<PartialIncomingFile> _createPartial(OfferedFile expected) async {
    final directory = await saveDirectory();
    await directory.create(recursive: true);
    return await PartialIncomingFile.create(directory, expected);
  }

  Future<Response> _pauseAfterBrokenUpload(
    IncomingTransfer transfer,
    int fileIndex,
  ) async {
    // Ended while it was stalled: nobody will come back for the bytes.
    if (transfer.isEnded) {
      await transfer.partials.remove(fileIndex)?.discard();
    } else {
      onInterrupted(transfer);
    }
    return Response(HttpStatus.serviceUnavailable);
  }
}

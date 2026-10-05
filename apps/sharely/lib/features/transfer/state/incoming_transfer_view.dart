import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sharely_core/sharely_core.dart';

enum IncomingTransferStage { offered, receiving, saved, failed }

/// One incoming transfer as the laptop notification shows it.
@immutable
final class IncomingTransferView {
  const new({
    required this.transferId,
    required this.senderName,
    required this.fileNames,
    required this.totalBytes,
    this.stage = IncomingTransferStage.offered,
    this.bytesReceived = 0,
    this.savedFiles = const [],
    this.failure,
  });

  final String transferId;
  final String senderName;
  final List<String> fileNames;
  final int totalBytes;
  final IncomingTransferStage stage;
  final int bytesReceived;
  final List<File> savedFiles;
  final TransferFailure? failure;

  double get fraction => totalBytes == 0 ? 1 : bytesReceived / totalBytes;

  IncomingTransferView copyWith({
    IncomingTransferStage? stage,
    int? bytesReceived,
    List<File>? savedFiles,
    TransferFailure? failure,
  }) {
    return IncomingTransferView(
      transferId: transferId,
      senderName: senderName,
      fileNames: fileNames,
      totalBytes: totalBytes,
      stage: stage ?? this.stage,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      savedFiles: savedFiles ?? this.savedFiles,
      failure: failure ?? this.failure,
    );
  }
}

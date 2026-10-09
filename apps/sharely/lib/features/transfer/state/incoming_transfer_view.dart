import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sharely_core/sharely_core.dart';

enum IncomingTransferStage { offered, receiving, saved, failed }

/// One incoming transfer as the laptop notification shows it.
@immutable
final class IncomingTransferView {
  const new({
    required this.transferId,
    required this.senderId,
    required this.senderName,
    required this.fileNames,
    required this.fileSizes,
    required this.totalBytes,
    this.stage = IncomingTransferStage.offered,
    this.bytesReceived = 0,
    this.savedFiles = const [],
    this.failure,
    this.isReconnecting = false,
  });

  final String transferId;
  final String senderId;
  final String senderName;
  final List<String> fileNames;
  final List<int> fileSizes;
  final int totalBytes;
  final IncomingTransferStage stage;
  final int bytesReceived;
  final List<File> savedFiles;
  final TransferFailure? failure;

  /// The connection dropped; the transfer continues by itself when it is
  /// back.
  final bool isReconnecting;

  double get fraction => totalBytes == 0 ? 1 : bytesReceived / totalBytes;

  IncomingTransferView copyWith({
    IncomingTransferStage? stage,
    int? bytesReceived,
    List<File>? savedFiles,
    TransferFailure? failure,
    bool? isReconnecting,
  }) {
    return IncomingTransferView(
      transferId: transferId,
      senderId: senderId,
      senderName: senderName,
      fileNames: fileNames,
      fileSizes: fileSizes,
      totalBytes: totalBytes,
      stage: stage ?? this.stage,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      savedFiles: savedFiles ?? this.savedFiles,
      failure: failure ?? this.failure,
      isReconnecting: isReconnecting ?? this.isReconnecting,
    );
  }
}

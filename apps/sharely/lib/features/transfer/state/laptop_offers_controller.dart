import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/app/android/background_transfer.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/background_receive_notice.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/laptop_messages.dart';
import 'package:sharely/features/transfer/state/laptop_reconnect.dart';
import 'package:sharely/features/transfer/state/phone_save_directory.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/speed_meter.dart';
import 'package:sharely_core/sharely_core.dart';

final laptopOffersProvider =
    NotifierProvider<LaptopOffersController, List<IncomingTransferView>>(
      LaptopOffersController.new,
    );

/// Phone side: offers from the laptop and their downloads, oldest first.
class LaptopOffersController extends Notifier<List<IncomingTransferView>> {
  /// Stops the laptop from stacking prompts faster than they are answered.
  static const maxUnansweredOffers = 3;

  /// Long enough to read "Saved"; the files stay listed under Recent.
  static const savedNoticeDuration = Duration(seconds: 6);

  final _unanswered = <String, OfferMessage>{};
  final _downloads = <String, IncomingDownload>{};
  final _dismissTimers = <Timer>[];

  @override
  List<IncomingTransferView> build() {
    final messages = ref.watch(laptopMessagesProvider).listen(_handleMessage);
    ref
      ..listen(laptopConnectionProvider, (_, connection) {
        if (connection is! LaptopConnected) _withdrawUnanswered();
      })
      ..onDispose(messages.cancel)
      ..onDispose(_stopEverything);
    return const [];
  }

  /// [alwaysFromLaptop] skips the prompt for this laptop from now on.
  void accept(String transferId, {bool alwaysFromLaptop = false}) {
    final offer = _unanswered.remove(transferId);
    final connection = ref.read(laptopConnectionProvider);
    final endpoint = connection is LaptopConnected
        ? connection.laptop.endpoint
        : null;
    if (offer == null || connection is! LaptopConnected || endpoint == null) {
      return dismiss(transferId);
    }
    if (alwaysFromLaptop) {
      unawaited(
        ref
            .read(pairedDevicesProvider.notifier)
            .setAlwaysAccept(connection.laptop.deviceId, isOn: true),
      );
    }
    _update(
      transferId,
      (view) => view.copyWith(stage: IncomingTransferStage.receiving),
    );
    unawaited(_download(offer, connection, endpoint));
  }

  void decline(String transferId) {
    final connection = ref.read(laptopConnectionProvider);
    if (_unanswered.remove(transferId) != null &&
        connection is LaptopConnected) {
      connection.connection.send(TransferDecisionMessage.reject(transferId));
    }
    dismiss(transferId);
  }

  void cancel(String transferId) => _downloads[transferId]?.cancel();

  void dismiss(String transferId) {
    state = [
      for (final view in state)
        if (view.transferId != transferId) view,
    ];
  }

  void _handleMessage(ProtocolMessage message) {
    switch (message) {
      case OfferMessage():
        _receiveOffer(message);
      // The laptop withdrew an offer nobody had answered yet.
      case TransferDecisionMessage(type: MessageType.cancel, :final transferId)
          when _unanswered.remove(transferId) != null:
        dismiss(transferId);
      default:
        break;
    }
  }

  void _receiveOffer(OfferMessage offer) {
    final connection = ref.read(laptopConnectionProvider);
    if (connection is! LaptopConnected) return;
    final transferId = offer.transferId;
    final isKnown = state.any((view) => view.transferId == transferId);
    if (isKnown || _unanswered.length >= maxUnansweredOffers) {
      connection.connection.send(TransferDecisionMessage.reject(transferId));
      return;
    }
    _unanswered[transferId] = offer;
    final laptop = connection.laptop;
    state = [
      ...state,
      IncomingTransferView(
        transferId: transferId,
        senderId: laptop.deviceId,
        senderName: laptop.deviceName,
        fileNames: [for (final file in offer.files) file.name],
        fileSizes: [for (final file in offer.files) file.sizeBytes],
        totalBytes: offer.totalBytes,
      ),
    ];
    if (_alwaysAccepts(laptop.deviceId)) accept(transferId);
  }

  // Read fresh: the connection's copy of the laptop predates the setting.
  bool _alwaysAccepts(String laptopId) {
    final devices = ref.read(pairedDevicesProvider).value ?? const [];
    return devices.any(
      (device) => device.deviceId == laptopId && device.alwaysAccept,
    );
  }

  Future<void> _download(
    OfferMessage offer,
    LaptopConnected connection,
    DeviceEndpoint endpoint,
  ) async {
    final transferId = offer.transferId;
    final localHello = await ref.read(localHelloProvider.future);
    final download = IncomingDownload.start(
      offer: offer,
      connection: connection.connection,
      endpoint: endpoint,
      authHeaders: buildAuthHeaders(
        localDeviceId: localHello.deviceId,
        authToken: connection.laptop.authToken,
      ),
      saveDirectory: ref.read(phoneSaveDirectoryProvider),
      reconnect: ref.read(laptopReconnectProvider),
    );
    _downloads[transferId] = download;
    final notice = BackgroundReceiveNotice(
      ref.read(backgroundTransferProvider),
      laptopName: connection.laptop.deviceName,
      fileCount: offer.files.length,
      totalBytes: offer.totalBytes,
    );
    unawaited(notice.start(onCancelRequested: () => cancel(transferId)));
    final speed = SpeedMeter();
    download.events.listen((event) => _applyEvent(event, notice, speed));
    await download.done;
    _downloads.remove(transferId);
  }

  void _applyEvent(
    IncomingTransferEvent event,
    BackgroundReceiveNotice notice,
    SpeedMeter speed,
  ) {
    if (!ref.mounted) return;
    final transferId = event.transferId;
    switch (event) {
      case IncomingTransferProgressed(:final bytesReceived):
        notice.showProgress(
          bytesReceived: bytesReceived,
          bytesPerSecond: speed.measure(bytesReceived),
        );
        _update(
          transferId,
          (view) => view.copyWith(
            bytesReceived: bytesReceived,
            isReconnecting: false,
          ),
        );
      case IncomingTransferInterrupted():
        speed.reset();
        notice.showReconnecting();
        _update(transferId, (view) => view.copyWith(isReconnecting: true));
      case IncomingTransferCompleted(:final savedFiles):
        unawaited(notice.end(null));
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
      case IncomingTransferEnded(:final reason):
        unawaited(notice.end(reason));
        _update(
          transferId,
          (view) => view.copyWith(
            stage: IncomingTransferStage.failed,
            failure: reason,
          ),
        );
      case IncomingOfferReceived():
        break;
    }
  }

  void _recordReceived(String transferId, List<File> savedFiles) {
    final view = state.where((view) => view.transferId == transferId);
    if (view.isEmpty) return;
    final sizes = view.first.fileSizes;
    final now = DateTime.now();
    ref.read(recentTransfersProvider.notifier).record([
      // Files are downloaded in offer order, so sizes line up by index.
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

  // Offers can't be answered without the connection they arrived on.
  void _withdrawUnanswered() {
    if (_unanswered.isEmpty) return;
    final withdrawn = {..._unanswered.keys};
    _unanswered.clear();
    state = [
      for (final view in state)
        if (!withdrawn.contains(view.transferId)) view,
    ];
  }

  void _stopEverything() {
    for (final timer in _dismissTimers) {
      timer.cancel();
    }
    for (final download in [..._downloads.values]) {
      download.cancel();
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

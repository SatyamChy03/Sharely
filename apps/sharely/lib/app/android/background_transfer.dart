import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

const _channel = MethodChannel('com.sharely/background_transfer');
final _log = Logger('BackgroundTransfer');

final backgroundTransferProvider = Provider<BackgroundTransfer>(
  (ref) => BackgroundTransfer(isSupported: Platform.isAndroid),
);

/// Keeps a send running, with a progress notification, after the user
/// leaves the app; without it Android freezes the app within seconds.
class BackgroundTransfer {
  new({required this.isSupported});

  /// False off Android, where every call does nothing.
  final bool isSupported;

  void Function()? _onCancelRequested;

  Future<void> start({
    required String title,
    required String text,
    required void Function() onCancelRequested,
  }) async {
    if (!isSupported) return;
    _onCancelRequested = onCancelRequested;
    _channel.setMethodCallHandler(_handleNativeCall);
    // Android 13+ hides the notification without this; the send runs anyway.
    unawaited(Permission.notification.request());
    await _invoke('start', {'title': title, 'text': text});
  }

  Future<void> update({
    required String title,
    required String text,
    required int percent,
  }) => _invoke('update', {'title': title, 'text': text, 'percent': percent});

  /// Leaves a notification saying how it went, if the user isn't watching.
  Future<void> finish({required String title, required String text}) async {
    if (!isSupported) return;
    _onCancelRequested = null;
    final isWatching =
        SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed;
    await _invoke(isWatching ? 'stop' : 'finish', {
      'title': title,
      'text': text,
    });
  }

  Future<void> stop() async {
    _onCancelRequested = null;
    await _invoke('stop', const {});
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'cancelRequested') _onCancelRequested?.call();
    return null;
  }

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      // The send itself doesn't depend on this, so carry on without it.
      _log.warning('Background transfer "$method" failed: ${error.code}');
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/pairing/state/camera_access_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/camera_permission_prompt.dart';
import 'package:sharely/features/pairing/widgets/qr_scanner.dart';
import 'package:sharely/features/pairing/widgets/scanner_viewfinder.dart';

/// The live scanner once the camera is allowed; a permission prompt before.
class ScanCameraArea extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ScanCameraArea> createState() => _ScanCameraAreaState();
}

class _ScanCameraAreaState extends ConsumerState<ScanCameraArea> {
  late final AppLifecycleListener _lifecycleListener;

  CameraAccessController get _cameraAccess =>
      ref.read(cameraAccessProvider.notifier);

  @override
  void initState() {
    super.initState();
    // The user may have allowed the camera in Settings while away.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_cameraAccess.recheckAfterResume()),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(cameraAccessProvider)) {
      AsyncData(value: CameraAccess.granted) => _buildScanner(),
      AsyncData(:final value) => _CameraPanel(
        child: CameraPermissionPrompt(
          access: value,
          onRequestAccess: () => unawaited(_cameraAccess.requestAccess()),
          onOpenSettings: () => unawaited(_cameraAccess.openSystemSettings()),
        ),
      ),
      AsyncError() => const _CameraPanel(child: _CameraUnavailableMessage()),
      _ => const _CameraPanel(child: SizedBox.shrink()),
    };
  }

  Widget _buildScanner() {
    final pairingState = ref.watch(phonePairingProvider);
    return ScannerViewfinder(
      isScanning: pairingState is PhoneReadyToScan,
      camera: ref.watch(qrScannerBuilderProvider)(
        context,
        ref.read(phonePairingProvider.notifier).pairWithScannedCode,
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SharelyColors.ink,
        borderRadius: BorderRadius.all(SharelyRadii.panel),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SharelySpacing.xl),
          child: child,
        ),
      ),
    );
  }
}

class _CameraUnavailableMessage extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Text(
      "Can't open the camera on this device. Restart Sharely and try again.",
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: SharelyColors.onInkSoft),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sharely/design/tokens.dart';

typedef QrScannerBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onCode,
);

/// Builds the live camera scanner. Overridden in tests, which have no camera.
final qrScannerBuilderProvider = Provider<QrScannerBuilder>(
  (ref) =>
      (context, onCode) => _CameraQrScanner(onCode: onCode),
);

class _CameraQrScanner extends StatefulWidget {
  const new({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<_CameraQrScanner> createState() => _CameraQrScannerState();
}

class _CameraQrScannerState extends State<_CameraQrScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text != null) {
        widget.onCode(text);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _handleDetection,
      errorBuilder: (context, error) => const _CameraUnavailable(),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SharelySpacing.xl),
        child: Text(
          'Camera is unavailable. Allow camera access for Sharely in '
          'your phone settings, then come back.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: SharelyColors.onInkSoft),
        ),
      ),
    );
  }
}

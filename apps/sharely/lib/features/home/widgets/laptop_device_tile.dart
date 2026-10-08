import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/pairing/widgets/paired_device_card.dart';
import 'package:sharely_core/sharely_core.dart';

/// One paired laptop on the phone's Devices tab, with what can be done to
/// it: connect or disconnect, and forget.
class LaptopDeviceTile extends StatelessWidget {
  const new({
    required this.laptop,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
    required this.onForget,
    super.key,
  });

  final PairedDevice laptop;
  final bool isConnected;

  /// Exactly one of these is offered. Null while a transfer is running.
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.sm,
      children: [
        PairedDeviceCard(device: laptop, isConnected: isConnected),
        Row(
          spacing: SharelySpacing.sm,
          children: [
            Expanded(
              child: isConnected
                  ? _TileButton(label: 'Disconnect', onPressed: onDisconnect)
                  : _TileButton(
                      label: 'Connect',
                      isPrimary: true,
                      onPressed: onConnect,
                    ),
            ),
            Expanded(
              child: _TileButton(label: 'Forget', onPressed: onForget),
            ),
          ],
        ),
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? SharelyColors.ink : SharelyColors.surface;
    final foreground = isPrimary ? SharelyColors.surface : SharelyColors.ink;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.4),
        disabledForegroundColor: foreground.withValues(alpha: 0.5),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: SharelyColors.mist, width: 1.5),
        ),
      ),
      child: Text(label),
    );
  }
}

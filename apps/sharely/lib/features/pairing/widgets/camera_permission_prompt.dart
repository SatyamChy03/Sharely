import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/camera_access_controller.dart';

/// Explains why Sharely needs the camera, with the one action that helps.
class CameraPermissionPrompt extends StatelessWidget {
  const new({
    required this.access,
    required this.onRequestAccess,
    required this.onOpenSettings,
    super.key,
  });

  final CameraAccess access;
  final VoidCallback onRequestAccess;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final (title, message, actionLabel) = switch (access) {
      CameraAccess.blocked => (
        'Turn on the camera in Settings',
        'Open Settings, go to Permissions, set Camera to Allow, then '
            'come back here.',
        'Open settings',
      ),
      CameraAccess.denied => (
        'Camera access is off',
        'Sharely needs the camera to scan the code on your laptop.',
        'Try again',
      ),
      _ => (
        'Allow camera access',
        'Sharely uses the camera only to scan the code on your laptop. '
            'Nothing is recorded or saved.',
        'Allow camera',
      ),
    };
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: SharelySpacing.md,
      children: [
        const _CameraBadge(),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(color: SharelyColors.surface),
        ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: SharelyColors.onInkSoft),
        ),
        const SizedBox(height: SharelySpacing.sm),
        SharelyButton(
          label: actionLabel,
          onPressed: access == CameraAccess.blocked
              ? onOpenSettings
              : onRequestAccess,
        ),
      ],
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: SharelyColors.inkRaised,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        LucideIcons.camera,
        size: 28,
        color: SharelyColors.accentOnInk,
      ),
    );
  }
}

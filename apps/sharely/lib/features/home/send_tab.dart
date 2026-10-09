import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/input_decoration.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/home/phone_send_actions.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

/// The Send tab: pick photos or files, or type something to send.
class SendTabView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SendTabView> createState() => _SendTabViewState();
}

class _SendTabViewState extends ConsumerState<SendTabView> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _sendTypedText() {
    if (sendTextFromPhone(context, ref, _text.text)) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(laptopConnectionProvider);
    final isConnected = connection is LaptopConnected;
    final canPick = isConnected && ref.watch(sendProvider) is SendIdle;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(SharelySpacing.page),
      children: [
        _Header(connection: connection),
        const SizedBox(height: SharelySpacing.page),
        _PickCard(
          icon: LucideIcons.image,
          title: 'Photos and videos',
          hint: 'Choose from your gallery',
          onTap: canPick
              ? () => unawaited(
                  pickAndSendFromPhone(context, ref, photosOnly: true),
                )
              : null,
        ),
        const SizedBox(height: 10),
        _PickCard(
          icon: LucideIcons.fileText,
          title: 'Files',
          hint: 'Documents, apps, archives and more',
          onTap: canPick
              ? () => unawaited(
                  pickAndSendFromPhone(context, ref, photosOnly: false),
                )
              : null,
        ),
        const SizedBox(height: SharelySpacing.xl),
        ..._buildTextComposer(textTheme, isConnected: isConnected),
      ],
    );
  }

  List<Widget> _buildTextComposer(
    TextTheme textTheme, {
    required bool isConnected,
  }) {
    return [
      Text('Text or link', style: textTheme.titleMedium),
      const SizedBox(height: SharelySpacing.md),
      TextField(
        controller: _text,
        minLines: 3,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        style: textTheme.bodyMedium,
        decoration: sharelyInputDecoration(
          hintText: 'A link, a note or an OTP…',
        ),
      ),
      const SizedBox(height: 10),
      Row(
        spacing: 10,
        children: [
          Expanded(
            child: SharelyButton(
              label: 'Clipboard',
              leadingIcon: LucideIcons.clipboard,
              variant: SharelyButtonVariant.secondary,
              onPressed: isConnected
                  ? () => unawaited(sendClipboardFromPhone(context, ref))
                  : null,
            ),
          ),
          Expanded(
            child: SharelyButton(
              label: 'Send text',
              leadingIcon: LucideIcons.arrowUp,
              onPressed: isConnected ? _sendTypedText : null,
            ),
          ),
        ],
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const new({required this.connection});

  final LaptopConnectionState connection;

  @override
  Widget build(BuildContext context) {
    final (name, tone) = switch (connection) {
      LaptopConnected(:final laptop) => (
        laptop.deviceName,
        StatusTone.connected,
      ),
      LaptopConnecting(:final laptop) => (
        laptop.deviceName,
        StatusTone.connecting,
      ),
      LaptopUnreachable(:final laptop) ||
      LaptopDisconnected(:final laptop) ||
      LaptopNeedsRepairing(
        :final laptop,
      ) => (laptop.deviceName, StatusTone.offline),
      LaptopNotPaired() => ('No laptop', StatusTone.offline),
    };
    return SizedBox(
      height: SharelySizes.minTouchTarget,
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          Text('Send', style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          Flexible(
            flex: 3,
            child: SurfaceCard(
              radius: SharelyRadii.row,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: SharelySpacing.sm,
                children: [
                  const Icon(
                    LucideIcons.laptop,
                    size: 15,
                    color: SharelyColors.textSecondary,
                  ),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  StatusDot(tone: tone),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: SharelyColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(SharelyRadii.zone),
          side: BorderSide(color: SharelyColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: SharelyColors.elevated,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              spacing: 14,
              children: [
                IconTile(icon: icon, background: SharelyColors.primaryTint),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(title, style: textTheme.labelLarge),
                      Text(
                        hint,
                        style: textTheme.bodySmall?.copyWith(
                          color: SharelyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: SharelyColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

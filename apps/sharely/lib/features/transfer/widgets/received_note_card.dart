import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/received_note.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('ReceivedNote');
final _shortCode = RegExp(r'^[A-Za-z0-9-]{4,12}$');

/// Text or a link from the other device, with Copy and (for links) Open.
class ReceivedNoteCard extends StatelessWidget {
  const new({
    required this.note,
    required this.sourceName,
    required this.onDismiss,
    super.key,
  });

  final ReceivedNote note;

  /// "laptop" or "phone": which of the user's devices sent it.
  final String sourceName;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final link = note.link;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 14),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(SharelyRadii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NoteHeader(
            label: link == null
                ? 'From your $sourceName'
                : 'Link from your $sourceName',
            onDismiss: onDismiss,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 12),
            child: _buildText(textTheme),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              spacing: 8,
              children: [
                if (link != null)
                  _NoteAction(
                    label: 'Open',
                    icon: LucideIcons.externalLink,
                    isPrimary: true,
                    onPressed: () => unawaited(_open(context, link)),
                  ),
                _NoteAction(
                  label: 'Copy',
                  icon: LucideIcons.copy,
                  isPrimary: link == null,
                  onPressed: () => unawaited(_copy(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(TextTheme textTheme) {
    // A short code such as an OTP is read digit by digit, so it gets room.
    if (_shortCode.hasMatch(note.text)) {
      return SelectableText(
        note.text,
        style: sharelyMonoStyle(size: 26, color: SharelyColors.ink),
      );
    }
    return SelectableText(
      note.text,
      minLines: 1,
      maxLines: 6,
      style: textTheme.bodyLarge?.copyWith(fontSize: 16),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: note.text));
    if (context.mounted) _showNotice(context, 'Copied.');
  }

  Future<void> _open(BuildContext context, Uri link) async {
    final isOpened = await launchUrl(
      link,
      mode: LaunchMode.externalApplication,
    );
    if (isOpened) return;
    _log.warning('No app could open the link');
    if (context.mounted) {
      _showNotice(context, "Couldn't open the link. Copy it instead.");
    }
  }

  void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoteHeader extends StatelessWidget {
  const new({required this.label, required this.onDismiss});

  final String label;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.slate),
          ),
        ),
        IconButton(
          onPressed: onDismiss,
          tooltip: 'Dismiss',
          constraints: const BoxConstraints.tightFor(
            width: SharelySizes.minTouchTarget,
            height: SharelySizes.minTouchTarget,
          ),
          icon: const Icon(LucideIcons.x, size: 16, color: SharelyColors.slate),
        ),
      ],
    );
  }
}

class _NoteAction extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, SharelySizes.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: isPrimary ? SharelyColors.ink : SharelyColors.paper,
        foregroundColor: isPrimary ? SharelyColors.surface : SharelyColors.ink,
        iconColor: isPrimary ? SharelyColors.surface : SharelyColors.ink,
        textStyle: Theme.of(context).textTheme.labelMedium,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}

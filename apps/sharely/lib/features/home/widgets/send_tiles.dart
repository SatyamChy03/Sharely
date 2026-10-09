import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// "What do you want to send?": four shortcuts in a two-by-two grid.
class SendTiles extends StatelessWidget {
  const new({
    required this.onPhotos,
    required this.onFiles,
    required this.onLink,
    required this.onClipboard,
    super.key,
  });

  /// Null while there is no laptop to send to.
  final VoidCallback? onPhotos;
  final VoidCallback? onFiles;
  final VoidCallback? onLink;
  final VoidCallback? onClipboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      children: [
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: _Tile(
                icon: LucideIcons.image,
                label: 'Photos',
                hint: 'Gallery',
                onTap: onPhotos,
              ),
            ),
            Expanded(
              child: _Tile(
                icon: LucideIcons.fileText,
                label: 'Files',
                hint: 'Docs & more',
                onTap: onFiles,
              ),
            ),
          ],
        ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: _Tile(
                icon: LucideIcons.link,
                label: 'Links',
                hint: 'Or a note',
                onTap: onLink,
              ),
            ),
            Expanded(
              child: _Tile(
                icon: LucideIcons.clipboard,
                label: 'Clipboard',
                hint: 'Copied text',
                onTap: onClipboard,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Container(
            height: 96,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: SharelyColors.primaryTint,
                    borderRadius: BorderRadius.all(SharelyRadii.button),
                  ),
                  child: Icon(icon, size: 20, color: SharelyColors.primary),
                ),
                _TileLabel(label: label, hint: hint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const new({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: SharelySpacing.sm,
      children: [
        Flexible(
          flex: 3,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge,
          ),
        ),
        Flexible(
          flex: 2,
          child: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w400,
              color: SharelyColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/laptop/widgets/dashed_border.dart';

/// "Drop anything here": the laptop's big send-to-phone target.
class DropZoneCard extends StatefulWidget {
  const new({
    required this.phoneName,
    required this.onChooseFiles,
    required this.onChooseFolder,
    required this.onDropPaths,
    super.key,
  });

  final String phoneName;
  final VoidCallback? onChooseFiles;
  final VoidCallback? onChooseFolder;

  /// Paths of files and folders dropped on the card; null disables dropping.
  final ValueChanged<List<String>>? onDropPaths;

  @override
  State<DropZoneCard> createState() => _DropZoneCardState();
}

class _DropZoneCardState extends State<DropZoneCard> {
  bool _isDraggingOver = false;

  void _setDraggingOver({required bool isOver}) =>
      setState(() => _isDraggingOver = isOver);

  @override
  Widget build(BuildContext context) {
    final onDropPaths = widget.onDropPaths;
    return DropTarget(
      enable: onDropPaths != null,
      onDragEntered: (_) => _setDraggingOver(isOver: true),
      onDragExited: (_) => _setDraggingOver(isOver: false),
      onDragDone: (details) {
        _setDraggingOver(isOver: false);
        onDropPaths?.call([for (final file in details.files) file.path]);
      },
      child: DashedBorder(
        color: _isDraggingOver ? SharelyColors.accent : SharelyColors.mistDeep,
        radius: 32,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
          decoration: BoxDecoration(
            color: _isDraggingOver
                ? SharelyColors.mistLight
                : SharelyColors.surface,
            borderRadius: const BorderRadius.all(SharelyRadii.panel),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      spacing: SharelySpacing.lg,
      children: [
        const _UploadBadge(),
        Text(
          _isDraggingOver ? 'Drop to send' : 'Drop anything here',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        Text(
          'Files and folders of any size go straight to ${widget.phoneName}',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: SharelyColors.slate,
            fontSize: 15,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _ZoneButton(
              label: 'Choose files',
              isPrimary: true,
              onPressed: widget.onChooseFiles,
            ),
            _ZoneButton(
              label: 'Choose folder',
              onPressed: widget.onChooseFolder,
            ),
          ],
        ),
      ],
    );
  }
}

class _UploadBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final ring = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: SharelyColors.mist),
    );
    return SizedBox.square(
      dimension: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: ring,
            child: const SizedBox.square(dimension: 120),
          ),
          DecoratedBox(
            decoration: ring,
            child: const SizedBox.square(dimension: 80),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: SharelyColors.ink,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: const Icon(
              LucideIcons.arrowUp,
              size: 26,
              color: SharelyColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneButton extends StatelessWidget {
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
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      backgroundColor: isPrimary ? SharelyColors.ink : SharelyColors.surface,
      foregroundColor: isPrimary ? SharelyColors.surface : SharelyColors.ink,
      disabledBackgroundColor: isPrimary
          ? SharelyColors.ink.withValues(alpha: 0.4)
          : SharelyColors.surface,
      disabledForegroundColor: isPrimary
          ? SharelyColors.surface.withValues(alpha: 0.7)
          : SharelyColors.slate,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        side: isPrimary
            ? BorderSide.none
            : const BorderSide(color: SharelyColors.mist, width: 1.5),
      ),
    );
    return TextButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

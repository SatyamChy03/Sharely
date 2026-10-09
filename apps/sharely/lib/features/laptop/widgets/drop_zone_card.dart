import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/dashed_border.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// "Drop anything here": the laptop's big send-to-phone target (D05, D07).
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
    final zone = AnimatedContainer(
      duration: SharelyMotion.medium,
      constraints: const BoxConstraints(minHeight: 380),
      padding: const EdgeInsets.all(SharelySpacing.xl),
      decoration: BoxDecoration(
        color: _isDraggingOver
            ? SharelyColors.primaryTint
            : SharelyColors.sunken,
        borderRadius: const BorderRadius.all(SharelyRadii.zone),
        border: _isDraggingOver
            ? Border.all(color: SharelyColors.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: SharelySpacing.xl),
          _buildContent(context),
          const SizedBox(height: SharelySpacing.xxl),
          _DirectNote(phoneName: widget.phoneName),
        ],
      ),
    );
    return DropTarget(
      enable: onDropPaths != null,
      onDragEntered: (_) => _setDraggingOver(isOver: true),
      onDragExited: (_) => _setDraggingOver(isOver: false),
      onDragDone: (details) {
        _setDraggingOver(isOver: false);
        onDropPaths?.call([for (final file in details.files) file.path]);
      },
      child: _isDraggingOver
          ? zone
          : DashedBorder(
              color: SharelyColors.lineHover,
              radius: 16,
              strokeWidth: 1.5,
              child: zone,
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      spacing: 14,
      children: [
        _buildIcon(),
        Semantics(
          liveRegion: true,
          child: Text(
            _isDraggingOver ? 'Drop to send' : 'Drop anything here',
            textAlign: TextAlign.center,
            style: textTheme.headlineLarge,
          ),
        ),
        Text(
          _isDraggingOver
              ? 'Release to send to ${widget.phoneName}'
              : 'Drag & drop files or folders',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
        if (!_isDraggingOver) ...[
          const _OrDivider(),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              SharelyButton(
                label: 'Choose files',
                leadingIcon: LucideIcons.file,
                height: SharelySizes.buttonMedium,
                isExpanded: false,
                onPressed: widget.onChooseFiles,
              ),
              SharelyButton(
                label: 'Choose folder',
                leadingIcon: LucideIcons.folder,
                variant: SharelyButtonVariant.secondary,
                height: SharelySizes.buttonMedium,
                isExpanded: false,
                onPressed: widget.onChooseFolder,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIcon() {
    return AnimatedContainer(
      duration: SharelyMotion.medium,
      curve: SharelyMotion.standard,
      width: 72,
      height: 72,
      transform: Matrix4.translationValues(0, _isDraggingOver ? -6 : 0, 0),
      decoration: BoxDecoration(
        color: _isDraggingOver ? SharelyColors.primary : SharelyColors.elevated,
        borderRadius: const BorderRadius.all(SharelyRadii.zone),
      ),
      child: Icon(
        LucideIcons.upload,
        size: 32,
        color: _isDraggingOver
            ? SharelyColors.onPrimary
            : SharelyColors.primary,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          const Expanded(child: Divider(height: 1, color: SharelyColors.line)),
          Text(
            'or',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
          const Expanded(child: Divider(height: 1, color: SharelyColors.line)),
        ],
      ),
    );
  }
}

class _DirectNote extends StatelessWidget {
  const new({required this.phoneName});

  final String phoneName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: SharelySpacing.sm,
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          size: 15,
          color: SharelyColors.primary,
        ),
        Flexible(
          child: Text(
            'Files go directly to $phoneName',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

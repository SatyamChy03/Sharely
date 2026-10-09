import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';

/// Offered files in a well: thumbnail, name and size, then the total.
class OfferFileRows extends StatelessWidget {
  const new({
    required this.fileNames,
    required this.fileSizes,
    required this.totalBytes,
    super.key,
    this.isCompact = false,
  });

  final List<String> fileNames;
  final List<int> fileSizes;
  final int totalBytes;

  /// Smaller rows for the laptop's notification card.
  final bool isCompact;

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hidden = fileNames.length - _maxShown;
    return Container(
      padding: const EdgeInsets.all(SharelySpacing.xs),
      decoration: BoxDecoration(
        color: isCompact ? SharelyColors.surface : SharelyColors.background,
        borderRadius: BorderRadius.all(
          isCompact ? SharelyRadii.row : SharelyRadii.tile,
        ),
        border: isCompact ? null : Border.all(color: SharelyColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, name) in fileNames.take(_maxShown).indexed)
            _FileRow(
              name: name,
              sizeBytes: index < fileSizes.length ? fileSizes[index] : 0,
              isCompact: isCompact,
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Text(
                '+$hidden more',
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.textSecondary,
                ),
              ),
            ),
          const Divider(height: 1, color: SharelyColors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: textTheme.bodySmall?.copyWith(
                    color: SharelyColors.textSecondary,
                  ),
                ),
                Text(
                  formatByteCount(totalBytes),
                  style: sharelyMonoStyle(
                    size: 13,
                    color: SharelyColors.text,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const new({
    required this.name,
    required this.sizeBytes,
    required this.isCompact,
  });

  final String name;
  final int sizeBytes;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isCompact ? 5 : 8),
      child: Row(
        spacing: isCompact ? 10 : SharelySpacing.md,
        children: [
          FileThumb.forName(name, size: isCompact ? 28 : 40),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: isCompact ? 13 : 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatByteCount(sizeBytes),
            style: sharelyMonoStyle(
              size: isCompact ? 12 : 13,
              color: isCompact
                  ? SharelyColors.textSecondary
                  : SharelyColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';

/// Offered files as rows: type badge, name and size.
class OfferFileRows extends StatelessWidget {
  const new({required this.fileNames, required this.fileSizes, super.key});

  final List<String> fileNames;
  final List<int> fileSizes;

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final hidden = fileNames.length - _maxShown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        for (final (index, name) in fileNames.take(_maxShown).indexed)
          _FileRow(
            name: name,
            sizeBytes: index < fileSizes.length ? fileSizes[index] : 0,
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 2),
            child: Text(
              '+$hidden more',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SharelyColors.slate),
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const new({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;

  static const _maxTypeChars = 5;

  String get _type {
    final dot = name.lastIndexOf('.');
    final extension = dot > 0 ? name.substring(dot + 1) : '';
    final isShown = extension.isNotEmpty && extension.length <= _maxTypeChars;
    return isShown ? extension.toUpperCase() : 'FILE';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: SharelyColors.paper,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: const BoxDecoration(
              color: SharelyColors.ink,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            child: Text(
              _type,
              style: sharelyMonoStyle(size: 11, color: SharelyColors.surface),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 15),
            ),
          ),
          Text(
            formatByteCount(sizeBytes),
            style: sharelyMonoStyle(size: 12, color: SharelyColors.slate),
          ),
        ],
      ),
    );
  }
}

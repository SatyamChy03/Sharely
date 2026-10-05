import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// Offered file names as chips, each tagged with its type.
class IncomingFileChips extends StatelessWidget {
  const new({required this.fileNames, super.key});

  final List<String> fileNames;

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final hidden = fileNames.length - _maxShown;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in fileNames.take(_maxShown)) _FileChip(name: name),
        if (hidden > 0) _FileChip(name: '+$hidden more', showType: false),
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  const new({required this.name, this.showType = true});

  final String name;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final dot = name.lastIndexOf('.');
    final type = dot > 0 ? name.substring(dot + 1).toUpperCase() : 'FILE';
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: SharelyColors.inkRaised,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (showType)
            Text(
              type,
              style: sharelyMonoStyle(
                size: 10,
                color: SharelyColors.accentOnInk,
              ),
            ),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SharelyColors.surface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

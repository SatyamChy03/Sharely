import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('Activity');

/// One activity line: a type tile, name, direction and size, then Show.
class ActivityRow extends StatelessWidget {
  const new({required this.transfer, super.key});

  final RecentTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isReceived = transfer.direction == TransferDirection.received;
    final dot = transfer.name.lastIndexOf('.');
    final extension = dot > 0 ? transfer.name.substring(dot + 1) : '';
    final savedFile = transfer.savedFile;
    return Row(
      spacing: SharelySpacing.md,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isReceived ? SharelyColors.ink : SharelyColors.mistLight,
            borderRadius: const BorderRadius.all(Radius.circular(11)),
          ),
          child: Text(
            extension.isEmpty ? 'FILE' : extension.toUpperCase(),
            maxLines: 1,
            style: sharelyMonoStyle(
              size: 10,
              color: isReceived ? SharelyColors.accentOnInk : SharelyColors.ink,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(
                transfer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${isReceived ? 'From phone' : 'To phone'} · '
                '${formatByteCount(transfer.sizeBytes)}',
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.slate,
                ),
              ),
            ],
          ),
        ),
        if (savedFile != null)
          TextButton(
            onPressed: () => unawaited(_showInFolder(savedFile.parent.path)),
            child: const Text('Show'),
          ),
      ],
    );
  }

  Future<void> _showInFolder(String folderPath) async {
    if (!await launchUrl(Uri.directory(folderPath))) {
      _log.warning('No app could open the save folder');
    }
  }
}

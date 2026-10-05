import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('IncomingResult');

/// After a transfer: open the save folder (if files arrived) or close.
class IncomingResultActions extends StatelessWidget {
  const new({required this.savedFiles, required this.onDismiss, super.key});

  final List<File> savedFiles;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (savedFiles.isNotEmpty)
          TextButton(
            onPressed: () => unawaited(_openSaveFolder()),
            child: const Text('Show in folder'),
          ),
        TextButton(onPressed: onDismiss, child: const Text('Close')),
      ],
    );
  }

  Future<void> _openSaveFolder() async {
    final folder = Uri.directory(savedFiles.first.parent.path);
    if (!await launchUrl(folder)) {
      _log.warning('No app could open the save folder');
    }
  }
}

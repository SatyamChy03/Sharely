import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/laptop/open_folder.dart';

/// After a transfer: open the save folder (if files arrived) or close.
class IncomingResultActions extends StatelessWidget {
  const new({required this.savedFiles, required this.onDismiss, super.key});

  final List<File> savedFiles;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: SharelySpacing.sm,
      children: [
        if (savedFiles.isNotEmpty)
          Expanded(
            child: SharelyButton(
              label: 'Show in folder',
              height: 40,
              onPressed: () =>
                  unawaited(openFolder(savedFiles.first.parent.path)),
            ),
          ),
        Expanded(
          child: SharelyButton(
            label: 'Close',
            variant: SharelyButtonVariant.secondary,
            height: 40,
            onPressed: onDismiss,
          ),
        ),
      ],
    );
  }
}

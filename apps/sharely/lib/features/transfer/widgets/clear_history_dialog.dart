import 'package:flutter/material.dart';

/// Asks before wiping the history list; true when the user confirms.
Future<bool> confirmClearHistory(BuildContext context) async {
  final isConfirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear history?'),
      content: const Text(
        'This removes the list on this device. Your files are not deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  return isConfirmed ?? false;
}

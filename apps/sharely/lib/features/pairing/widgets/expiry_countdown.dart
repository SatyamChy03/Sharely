import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// "New code in 4:52", ticking once a second.
class ExpiryCountdown extends StatefulWidget {
  const new({required this.expiresAt, super.key});

  final DateTime expiresAt;

  @override
  State<ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<ExpiryCountdown> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes;
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: SharelySpacing.sm,
      children: [
        const Icon(
          LucideIcons.clock,
          size: 14,
          color: SharelyColors.textSecondary,
        ),
        Text(
          'New code in',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SharelyColors.textSecondary),
        ),
        Text(
          '$minutes:$seconds',
          style: sharelyMonoStyle(size: 13, color: SharelyColors.text),
        ),
      ],
    );
  }
}

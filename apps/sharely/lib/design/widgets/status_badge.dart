import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

enum StatusTone { connected, connecting, offline, success, failed }

extension StatusToneColors on StatusTone {
  Color get foreground => switch (this) {
    StatusTone.connected => SharelyColors.primary,
    StatusTone.connecting => SharelyColors.primarySoft,
    StatusTone.offline => SharelyColors.textSecondary,
    StatusTone.success => SharelyColors.success,
    StatusTone.failed => SharelyColors.dangerText,
  };

  Color get tint => switch (this) {
    StatusTone.connected || StatusTone.connecting => SharelyColors.primaryTint,
    StatusTone.offline => SharelyColors.neutralTint,
    StatusTone.success => SharelyColors.successTint,
    StatusTone.failed => SharelyColors.dangerTint,
  };

  // A hollow dot tells "not there yet" apart without relying on colour.
  bool get hasFilledDot => switch (this) {
    StatusTone.connected || StatusTone.success || StatusTone.failed => true,
    StatusTone.connecting || StatusTone.offline => false,
  };
}

/// A state as a dot plus words; a tinted badge unless [isPlain].
class StatusBadge extends StatelessWidget {
  const new({
    required this.label,
    required this.tone,
    super.key,
    this.isPlain = false,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final bool isPlain;

  /// Replaces the dot, for file states such as a tick or an arrow.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (glyph == null)
          StatusDot(tone: tone)
        else
          Icon(glyph, size: 14, color: tone.foreground),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w500, color: tone.foreground),
          ),
        ),
      ],
    );
    if (isPlain) return content;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: const BorderRadius.all(SharelyRadii.badge),
      ),
      child: content,
    );
  }
}

class StatusDot extends StatelessWidget {
  const new({required this.tone, super.key});

  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.hasFilledDot ? tone.foreground : null,
        border: Border.all(color: tone.foreground, width: 1.5),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/flow_dots.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/pulse_rings.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/pairing/widgets/pairing_step_header.dart';

/// Step 2 of pairing (M04): the phone is finding or joining the laptop.
class PairingProgressView extends StatelessWidget {
  const new({required this.onCancel, super.key, this.laptopName});

  /// Null while the phone is still looking for a laptop to try the code on.
  final String? laptopName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = laptopName;
    final title = name == null
        ? 'Looking for your laptop'
        : 'Connecting to $name';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PairingStepHeader(currentStep: 2),
        const Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: _DevicesLinking()),
        ),
        const Gap(SharelySpacing.xl),
        Semantics(
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium,
          ),
        ),
        const Gap(SharelySpacing.sm),
        Text(
          'Keep both devices on the same Wi-Fi.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
        const Gap(SharelySpacing.xl),
        _StepList(hasFoundLaptop: name != null),
        const Spacer(),
        SharelyButton(
          label: 'Cancel',
          variant: SharelyButtonVariant.secondary,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _DevicesLinking extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        height: 200,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: SharelySpacing.md,
          children: [
            IconTile(
              icon: LucideIcons.smartphone,
              size: 72,
              radius: SharelyRadii.zone,
              color: SharelyColors.text,
              background: SharelyColors.surface,
              borderColor: SharelyColors.lineStrong,
            ),
            FlowDots(),
            PulseRings(
              size: 72,
              child: IconTile(
                icon: LucideIcons.laptop,
                size: 72,
                radius: SharelyRadii.zone,
                borderColor: SharelyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepStatus { done, active, waiting }

class _StepList extends StatelessWidget {
  const new({required this.hasFoundLaptop});

  final bool hasFoundLaptop;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: SharelyRadii.zone,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _StepRow(
            'Laptop found',
            hasFoundLaptop ? _StepStatus.done : _StepStatus.active,
          ),
          _StepRow(
            'Pairing',
            hasFoundLaptop ? _StepStatus.active : _StepStatus.waiting,
          ),
          const _StepRow('Ready to transfer', _StepStatus.waiting),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const new(this.label, this.status);

  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (note, noteColor) = switch (status) {
      _StepStatus.done => ('Done', SharelyColors.success),
      _StepStatus.active => ('In progress', SharelyColors.primarySoft),
      _StepStatus.waiting => ('', SharelyColors.textSecondary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        spacing: 14,
        children: [
          SizedBox.square(dimension: 24, child: Center(child: _marker())),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: status == _StepStatus.active
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: status == _StepStatus.waiting
                    ? SharelyColors.textSecondary
                    : SharelyColors.text,
              ),
            ),
          ),
          Text(note, style: textTheme.labelSmall?.copyWith(color: noteColor)),
        ],
      ),
    );
  }

  Widget _marker() => switch (status) {
    _StepStatus.done => Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SharelyColors.success,
      ),
      child: const Icon(
        LucideIcons.check,
        size: 13,
        color: SharelyColors.onPrimary,
      ),
    ),
    _StepStatus.active => const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: SharelyColors.primary,
        backgroundColor: SharelyColors.lineStrong,
      ),
    ),
    _StepStatus.waiting => Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SharelyColors.lineStrong, width: 1.5),
      ),
    ),
  };
}

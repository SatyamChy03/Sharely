import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Where the files go, "always accept", then Decline and Accept.
class LaptopOfferDecision extends StatefulWidget {
  const new({required this.onAccept, required this.onDecline, super.key});

  /// Called with whether to skip this prompt for the laptop from now on.
  final ValueChanged<bool> onAccept;
  final VoidCallback onDecline;

  @override
  State<LaptopOfferDecision> createState() => _LaptopOfferDecisionState();
}

class _LaptopOfferDecisionState extends State<LaptopOfferDecision> {
  bool _alwaysAccept = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(
            minHeight: SharelySizes.minTouchTarget,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: SharelyColors.mistLight)),
          ),
          child: Row(
            spacing: 10,
            children: [
              const Icon(LucideIcons.folder, size: 18),
              Text(
                'Downloads/Sharely',
                style: textTheme.bodyMedium?.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
        CheckboxListTile(
          value: _alwaysAccept,
          onChanged: (value) => setState(() => _alwaysAccept = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: SharelyColors.ink,
          checkColor: SharelyColors.surface,
          title: Text(
            'Always accept from this laptop',
            style: textTheme.bodyMedium?.copyWith(fontSize: 15),
          ),
        ),
        const SizedBox(height: SharelySpacing.sm),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: SheetButton(label: 'Decline', onPressed: widget.onDecline),
            ),
            Expanded(
              child: SheetButton(
                label: 'Accept',
                isPrimary: true,
                onPressed: () => widget.onAccept(_alwaysAccept),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The 58-high buttons at the foot of the phone's incoming sheet.
class SheetButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 58),
        backgroundColor: isPrimary ? SharelyColors.ink : SharelyColors.paper,
        foregroundColor: isPrimary ? SharelyColors.surface : SharelyColors.ink,
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(SharelyRadii.button),
        ),
      ),
      child: Text(label),
    );
  }
}

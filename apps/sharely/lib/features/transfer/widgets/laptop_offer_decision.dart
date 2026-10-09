import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// "Always accept", then Decline and Accept.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.sm,
      children: [
        CheckboxListTile(
          value: _alwaysAccept,
          onChanged: (value) => setState(() => _alwaysAccept = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'Always accept from this laptop',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: SharelyButton(
                label: 'Decline',
                variant: SharelyButtonVariant.secondary,
                onPressed: widget.onDecline,
              ),
            ),
            Expanded(
              flex: 2,
              child: SharelyButton(
                label: 'Accept',
                leadingIcon: LucideIcons.check,
                onPressed: () => widget.onAccept(_alwaysAccept),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

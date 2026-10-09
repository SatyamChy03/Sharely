import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// "Always accept" plus Decline and Accept; Accept is the one accent.
class IncomingOfferActions extends StatefulWidget {
  const new({required this.onAccept, required this.onDecline, super.key});

  /// Called with whether to skip this prompt for the sender from now on.
  final ValueChanged<bool> onAccept;
  final VoidCallback onDecline;

  @override
  State<IncomingOfferActions> createState() => _IncomingOfferActionsState();
}

class _IncomingOfferActionsState extends State<IncomingOfferActions> {
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
            'Always accept from this phone',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Row(
          spacing: SharelySpacing.sm,
          children: [
            Expanded(
              child: SharelyButton(
                label: 'Decline',
                variant: SharelyButtonVariant.secondary,
                height: 40,
                onPressed: widget.onDecline,
              ),
            ),
            Expanded(
              child: SharelyButton(
                label: 'Accept',
                leadingIcon: LucideIcons.check,
                height: 40,
                onPressed: () => widget.onAccept(_alwaysAccept),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

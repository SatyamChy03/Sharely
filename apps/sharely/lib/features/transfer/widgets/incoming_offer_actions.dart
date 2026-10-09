import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

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
      spacing: 16,
      children: [
        CheckboxListTile(
          value: _alwaysAccept,
          onChanged: (value) => setState(() => _alwaysAccept = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: SharelyColors.accentOnInk,
          checkColor: SharelyColors.ink,
          title: Text(
            'Always accept from this phone',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: SharelyColors.onInkSoft),
          ),
        ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: NotificationButton(
                label: 'Decline',
                onPressed: widget.onDecline,
              ),
            ),
            Expanded(
              child: NotificationButton(
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

/// The 48-high buttons used inside laptop notifications.
class NotificationButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: isPrimary ? SharelyColors.accent : Colors.transparent,
        foregroundColor: SharelyColors.surface,
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(
                  color: SharelyColors.inkBorderStrong,
                  width: 1.5,
                ),
        ),
      ),
      child: Text(label),
    );
  }
}

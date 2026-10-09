import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely_core/sharely_core.dart';

/// More than one laptop answered: pick yours, so the code goes only there.
class LaptopChoiceList extends StatelessWidget {
  const new({required this.laptops, required this.onChosen, super.key});

  final List<FoundLaptop> laptops;
  final ValueChanged<FoundLaptop> onChosen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.sm,
      children: [
        Text(
          'Which laptop is yours?',
          style: textTheme.titleSmall?.copyWith(color: SharelyColors.ink),
        ),
        for (final laptop in laptops)
          Material(
            color: SharelyColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: ListTile(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              leading: const Icon(LucideIcons.laptop, color: SharelyColors.ink),
              title: Text(laptop.hello.deviceName),
              subtitle: Text(laptop.endpoint.host.address),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => onChosen(laptop),
            ),
          ),
      ],
    );
  }
}

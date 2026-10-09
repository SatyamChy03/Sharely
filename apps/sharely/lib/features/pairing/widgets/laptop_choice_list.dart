import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
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
        Text('Which laptop is yours?', style: textTheme.titleSmall),
        for (final laptop in laptops)
          Material(
            color: SharelyColors.sunken,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(SharelyRadii.zone),
              side: BorderSide(color: SharelyColors.line, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const IconTile(icon: LucideIcons.laptop, size: 42),
              title: Text(laptop.hello.deviceName, style: textTheme.titleSmall),
              subtitle: Text(
                laptop.endpoint.host.address,
                style: sharelyMonoStyle(
                  size: 12,
                  color: SharelyColors.textSecondary,
                ),
              ),
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: SharelyColors.textSecondary,
              ),
              onTap: () => onChosen(laptop),
            ),
          ),
      ],
    );
  }
}

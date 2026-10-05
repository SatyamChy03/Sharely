import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

enum HomeTab { home, history, devices }

/// Floating ink capsule with the three phone sections.
class PillNav extends StatelessWidget {
  const new({required this.current, required this.onSelected, super.key});

  final HomeTab current;
  final ValueChanged<HomeTab> onSelected;

  static const List<({HomeTab tab, IconData icon, String label})> _items = [
    (tab: HomeTab.home, icon: LucideIcons.house, label: 'Home'),
    (tab: HomeTab.history, icon: LucideIcons.clock, label: 'History'),
    (tab: HomeTab.devices, icon: LucideIcons.smartphone, label: 'Devices'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: SharelyColors.ink,
        borderRadius: BorderRadius.all(SharelyRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          for (final item in _items)
            _PillItem(
              icon: item.icon,
              label: item.label,
              isSelected: item.tab == current,
              onTap: () => onSelected(item.tab),
            ),
        ],
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? SharelyColors.onAccent : SharelyColors.mist;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? SharelyColors.accent : Colors.transparent,
        borderRadius: const BorderRadius.all(SharelyRadii.chip),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedSize(
            duration: SharelyMotion.fast,
            child: Container(
              height: 48,
              constraints: const BoxConstraints(minWidth: 48),
              padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  Icon(icon, size: 19, color: color),
                  if (isSelected)
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: color, fontSize: 14),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

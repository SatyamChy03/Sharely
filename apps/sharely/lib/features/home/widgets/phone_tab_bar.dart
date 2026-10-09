import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

enum HomeTab {
  home('Home', LucideIcons.house),
  send('Send', LucideIcons.arrowUp),
  activity('Activity', LucideIcons.clock),
  devices('Devices', LucideIcons.monitorSmartphone),
  settings('Settings', LucideIcons.settings);

  new(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The phone's bottom navigation: five sections, the current one in cyan.
class PhoneTabBar extends StatelessWidget {
  const new({required this.current, required this.onSelected, super.key});

  final HomeTab current;
  final ValueChanged<HomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        border: Border(top: BorderSide(color: SharelyColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: SharelySizes.tabBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final tab in HomeTab.values)
                  Expanded(
                    child: _TabItem(
                      tab: tab,
                      isSelected: tab == current,
                      onTap: () => onSelected(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const new({required this.tab, required this.isSelected, required this.onTap});

  final HomeTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? SharelyColors.primary
        : SharelyColors.textSecondary;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(SharelyRadii.button),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            AnimatedContainer(
              duration: SharelyMotion.fast,
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected ? SharelyColors.primaryTint : null,
                borderRadius: const BorderRadius.all(SharelyRadii.pill),
              ),
              child: Icon(tab.icon, size: 22, color: color),
            ),
            Text(
              tab.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 0.1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

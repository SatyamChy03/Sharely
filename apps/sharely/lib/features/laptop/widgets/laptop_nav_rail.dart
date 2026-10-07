import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';

enum LaptopSection { home, history, devices }

/// Ink side rail on the laptop: logo, sections, and settings at the bottom.
class LaptopNavRail extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelect,
    required this.onComingSoon,
    super.key,
  });

  final LaptopSection selected;
  final ValueChanged<LaptopSection> onSelect;
  final ValueChanged<String> onComingSoon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SharelyColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        spacing: SharelySpacing.sm,
        children: [
          const SizedBox.square(
            dimension: 48,
            child: Center(child: SharelyLogoMark(size: 34)),
          ),
          const SizedBox(height: SharelySpacing.lg),
          _RailButton(
            icon: LucideIcons.house,
            label: 'Home',
            isSelected: selected == LaptopSection.home,
            onTap: () => onSelect(LaptopSection.home),
          ),
          _RailButton(
            icon: LucideIcons.clock,
            label: 'History',
            isSelected: selected == LaptopSection.history,
            onTap: () => onSelect(LaptopSection.history),
          ),
          _RailButton(
            icon: LucideIcons.smartphone,
            label: 'Devices',
            isSelected: selected == LaptopSection.devices,
            onTap: () => onSelect(LaptopSection.devices),
          ),
          const Spacer(),
          _RailButton(
            icon: LucideIcons.settings,
            label: 'Settings',
            onTap: () => onComingSoon('Settings'),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: isSelected ? SharelyColors.accent : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          onTap: isSelected ? null : onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? SharelyColors.onAccent
                  : SharelyColors.onInkQuiet,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}

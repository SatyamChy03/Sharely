import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/design/widgets/status_badge.dart';

enum LaptopSection {
  home('Home', LucideIcons.house),
  send('Send', LucideIcons.arrowUp),
  receive('Receive', LucideIcons.arrowDown),
  activity('Activity', LucideIcons.clock),
  devices('Devices', LucideIcons.monitorSmartphone),
  settings('Settings', LucideIcons.settings);

  new(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The laptop's sidebar: wordmark, sections, and this device at the bottom.
class LaptopSidebar extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelect,
    required this.deviceName,
    required this.isConnected,
    super.key,
    this.isCompact = false,
  });

  final LaptopSection selected;
  final ValueChanged<LaptopSection> onSelect;
  final String deviceName;

  /// Whether a paired phone is connected right now.
  final bool isConnected;

  /// Icons only, for windows too narrow for the full sidebar.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? 68 : SharelySizes.sidebarWidth,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        border: Border(right: BorderSide(color: SharelyColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: isCompact
                  ? const SharelyLogoMark()
                  : const SharelyWordmark(),
            ),
          ),
          for (final section in LaptopSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _SidebarItem(
                section: section,
                isSelected: section == selected,
                isCompact: isCompact,
                onTap: () => onSelect(section),
              ),
            ),
          const Spacer(),
          if (!isCompact)
            _ThisDeviceCard(deviceName: deviceName, isConnected: isConnected),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const new({
    required this.section,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  final LaptopSection section;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? SharelyColors.elevated : Colors.transparent,
        borderRadius: const BorderRadius.all(SharelyRadii.row),
        child: InkWell(
          onTap: isSelected ? null : onTap,
          borderRadius: const BorderRadius.all(SharelyRadii.row),
          hoverColor: SharelyColors.elevated,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              spacing: SharelySpacing.md,
              children: [
                Icon(
                  section.icon,
                  size: 18,
                  semanticLabel: isCompact ? section.label : null,
                  color: isSelected
                      ? SharelyColors.primary
                      : SharelyColors.textSecondary,
                ),
                if (!isCompact)
                  Text(
                    section.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? SharelyColors.text
                          : SharelyColors.textSecondary,
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

class _ThisDeviceCard extends StatelessWidget {
  const new({required this.deviceName, required this.isConnected});

  final String deviceName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(SharelySpacing.md),
      decoration: BoxDecoration(
        color: SharelyColors.sunken,
        borderRadius: const BorderRadius.all(SharelyRadii.tile),
        border: Border.all(color: SharelyColors.line),
      ),
      child: Row(
        spacing: 10,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SharelyColors.elevated,
            ),
            child: Text(
              deviceName.isEmpty ? '' : deviceName[0].toUpperCase(),
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: SharelyColors.primarySoft,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                StatusBadge(
                  label: isConnected ? 'Connected' : 'Offline',
                  tone: isConnected ? StatusTone.connected : StatusTone.offline,
                  isPlain: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

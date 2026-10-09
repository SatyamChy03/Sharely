import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sharely_switch.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/laptop/open_folder.dart';
import 'package:sharely/features/laptop/widgets/laptop_page.dart';
import 'package:sharely/features/laptop/widgets/page_heading.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/save_folder.dart';

/// Laptop Settings (D15): what this laptop accepts and where it saves.
class LaptopSettingsView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final folder = ref.watch(laptopSaveFolderProvider).value?.path;
    final paired = ref.read(pairedDevicesProvider.notifier);
    return LaptopPage(
      maxWidth: 760,
      children: [
        const PageHeading(title: 'Settings'),
        _Panel(
          title: 'Transfer',
          rows: [
            for (final device in devices)
              _SettingRow(
                label: 'Always accept from ${device.deviceName}',
                help: 'Save its files right away, without asking first.',
                control: SharelySwitch(
                  label: 'Always accept from ${device.deviceName}',
                  value: device.alwaysAccept,
                  onChanged: (isOn) => unawaited(
                    paired.setAlwaysAccept(device.deviceId, isOn: isOn),
                  ),
                ),
              ),
            if (folder != null)
              _SettingRow(
                label: 'Download folder',
                help: 'Received files are saved here.',
                control: _FolderControl(path: folder),
              ),
          ],
        ),
        const _Panel(
          title: 'General',
          rows: [
            _SettingRow(
              label: 'Appearance',
              help: 'Sharely has one look, built for long sessions.',
              control: _Value('Dark'),
            ),
            _SettingRow(
              label: 'Who can send to this laptop',
              help: 'A device must scan your code once before it can send.',
              control: _Value('Paired only'),
            ),
            _SettingRow(
              label: 'About',
              help: 'Files go directly between your devices on your Wi-Fi.',
              control: _Value('No ads · No account'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const new({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 18),
            ),
          ),
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const Divider(height: 1, color: SharelyColors.line),
            row,
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const new({required this.label, required this.help, required this.control});

  final String label;
  final String help;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SharelySpacing.lg,
        runSpacing: SharelySpacing.sm,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  help,
                  style: textTheme.bodySmall?.copyWith(
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          control,
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: SharelyColors.textSecondary,
      ),
    );
  }
}

class _FolderControl extends StatelessWidget {
  const new({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: SharelySpacing.sm,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SharelyColors.background,
              borderRadius: const BorderRadius.all(SharelyRadii.button),
              border: Border.all(color: SharelyColors.lineStrong),
            ),
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sharelyMonoStyle(size: 12, color: SharelyColors.text),
            ),
          ),
        ),
        SharelyButton(
          label: 'Open',
          variant: SharelyButtonVariant.secondary,
          height: 38,
          isExpanded: false,
          onPressed: () => unawaited(openFolder(path)),
        ),
      ],
    );
  }
}

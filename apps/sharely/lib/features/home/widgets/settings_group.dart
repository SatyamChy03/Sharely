import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/section_label.dart';
import 'package:sharely/design/widgets/surface_card.dart';

/// A labelled card of settings rows with hairlines between them.
class SettingsGroup extends StatelessWidget {
  const new({required this.label, required this.rows, super.key});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        SectionLabel(label),
        SurfaceCard(
          radius: SharelyRadii.zone,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                if (index > 0)
                  const Divider(height: 1, color: SharelyColors.line),
                row,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

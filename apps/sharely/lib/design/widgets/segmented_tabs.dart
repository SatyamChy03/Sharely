import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// A row of mutually exclusive filters; the chosen one is raised.
class SegmentedTabs<T> extends StatelessWidget {
  const new({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    super.key,
    this.isExpanded = true,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (final value in values)
        if (isExpanded)
          Expanded(child: _segment(context, value))
        else
          _segment(context, value),
    ];
    return Container(
      padding: const EdgeInsets.all(SharelySpacing.xs),
      decoration: BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: const BorderRadius.all(SharelyRadii.button),
        border: Border.all(color: SharelyColors.line),
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        spacing: SharelySpacing.xs,
        children: segments,
      ),
    );
  }

  Widget _segment(BuildContext context, T value) {
    final isSelected = value == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: const BorderRadius.all(Radius.circular(7)),
        child: AnimatedContainer(
          duration: SharelyMotion.fast,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? SharelyColors.elevated : null,
            borderRadius: const BorderRadius.all(Radius.circular(7)),
          ),
          child: Text(
            labelOf(value),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? SharelyColors.text
                  : SharelyColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

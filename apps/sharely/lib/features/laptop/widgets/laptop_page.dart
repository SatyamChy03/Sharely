import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// The scrolling body of a laptop section: a column of bounded width,
/// centred in whatever room the window gives it.
class LaptopPage extends StatelessWidget {
  const new({
    required this.children,
    super.key,
    this.maxWidth = 1100,
    this.isVerticallyCentered = false,
  });

  final List<Widget> children;
  final double maxWidth;

  /// For a page that is one message, such as a finished transfer.
  final bool isVerticallyCentered;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 660;
        const verticalPadding = SharelySpacing.xxl;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? SharelySpacing.xl : 40,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            // At least the window's height, so centring has room to work.
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - verticalPadding * 2,
            ),
            child: Align(
              alignment: isVerticallyCentered
                  ? Alignment.center
                  : Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: SharelySpacing.xl,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

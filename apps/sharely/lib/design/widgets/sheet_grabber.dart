import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// The short bar at the top of a bottom sheet.
class SheetGrabber extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: const BoxDecoration(
        color: SharelyColors.lineStrong,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}

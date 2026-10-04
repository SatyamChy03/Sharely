import 'package:flutter/material.dart';

abstract final class SharelyFonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

/// Geist text theme: heavy, tightly tracked headings over a calm body.
TextTheme buildSharelyTextTheme(Color textColor) {
  TextStyle style(double size, FontWeight weight, {double tracking = 0}) {
    return TextStyle(
      fontFamily: SharelyFonts.sans,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: size >= 28 ? 1.06 : 1.4,
      color: textColor,
    );
  }

  return TextTheme(
    displayLarge: style(56, FontWeight.w800, tracking: -2.6),
    displayMedium: style(40, FontWeight.w800, tracking: -1.8),
    headlineLarge: style(32, FontWeight.w800, tracking: -1.2),
    headlineMedium: style(24, FontWeight.w800, tracking: -0.8),
    titleLarge: style(20, FontWeight.w700, tracking: -0.4),
    titleMedium: style(17, FontWeight.w700, tracking: -0.3),
    titleSmall: style(15, FontWeight.w600),
    bodyLarge: style(17, FontWeight.w400),
    bodyMedium: style(15, FontWeight.w400),
    bodySmall: style(13, FontWeight.w400),
    labelLarge: style(17, FontWeight.w700),
    labelMedium: style(14, FontWeight.w600),
    labelSmall: style(12, FontWeight.w600),
  );
}

/// Monospace style for speeds, sizes, codes and counters.
TextStyle sharelyMonoStyle({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w600,
}) {
  return TextStyle(
    fontFamily: SharelyFonts.mono,
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

import 'package:flutter/material.dart';

abstract final class SharelyFonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

/// Geist text theme: one family, tight at the top.
TextTheme buildSharelyTextTheme(Color textColor) {
  TextStyle style(double size, FontWeight weight, {double tracking = 0}) {
    return TextStyle(
      fontFamily: SharelyFonts.sans,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: size >= 22 ? 1.12 : 1.4,
      color: textColor,
    );
  }

  return TextTheme(
    displayLarge: style(48, FontWeight.w700, tracking: -1.5),
    displayMedium: style(38, FontWeight.w700, tracking: -1.4),
    displaySmall: style(32, FontWeight.w700, tracking: -0.9),
    headlineLarge: style(30, FontWeight.w700, tracking: -0.8),
    headlineMedium: style(24, FontWeight.w700, tracking: -0.6),
    headlineSmall: style(22, FontWeight.w700, tracking: -0.5),
    titleLarge: style(20, FontWeight.w600, tracking: -0.3),
    titleMedium: style(17, FontWeight.w600, tracking: -0.2),
    titleSmall: style(15, FontWeight.w600),
    bodyLarge: style(16, FontWeight.w400),
    bodyMedium: style(15, FontWeight.w400),
    bodySmall: style(13, FontWeight.w400),
    labelLarge: style(16, FontWeight.w600),
    labelMedium: style(14, FontWeight.w500),
    labelSmall: style(12, FontWeight.w500),
  );
}

/// Monospace style for speeds, sizes, codes and counters.
TextStyle sharelyMonoStyle({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
  double tracking = 0,
}) {
  return TextStyle(
    fontFamily: SharelyFonts.mono,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

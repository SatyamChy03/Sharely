import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// Light (Paper) and dark (Ink) themes. Dark screens wrap themselves in [dark].
abstract final class SharelyTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: SharelyColors.ink,
      secondary: SharelyColors.accent,
      onSecondary: SharelyColors.onAccent,
      onSurface: SharelyColors.ink,
      onSurfaceVariant: SharelyColors.slate,
      outline: SharelyColors.paperBorder,
    );
    return _base(scheme, SharelyColors.paper);
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: SharelyColors.accent,
      onPrimary: SharelyColors.onAccent,
      secondary: SharelyColors.accent,
      onSecondary: SharelyColors.onAccent,
      surface: SharelyColors.inkRaised,
      onSurfaceVariant: SharelyColors.onInkSoft,
      outline: SharelyColors.inkBorderStrong,
    );
    return _base(scheme, SharelyColors.ink);
  }

  static ThemeData _base(ColorScheme scheme, Color background) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: SharelyFonts.sans,
      textTheme: buildSharelyTextTheme(scheme.onSurface),
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

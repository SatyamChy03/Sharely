import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// The app has one appearance: dark, with elevation shown by tone.
abstract final class SharelyTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: SharelyColors.primary,
      onPrimary: SharelyColors.onPrimary,
      secondary: SharelyColors.primary,
      onSecondary: SharelyColors.onPrimary,
      surface: SharelyColors.surface,
      onSurface: SharelyColors.text,
      onSurfaceVariant: SharelyColors.textSecondary,
      outline: SharelyColors.lineStrong,
      outlineVariant: SharelyColors.line,
      error: SharelyColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: SharelyColors.background,
      fontFamily: SharelyFonts.sans,
      textTheme: buildSharelyTextTheme(SharelyColors.text),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: SharelyColors.elevated,
      focusColor: SharelyColors.elevated,
      dividerColor: SharelyColors.line,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: SharelyColors.primary,
        selectionColor: SharelyColors.primaryTint,
        selectionHandleColor: SharelyColors.primary,
      ),
      snackBarTheme: _snackBarTheme,
      checkboxTheme: _checkboxTheme(),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SharelyColors.primary,
          textStyle: const TextStyle(
            fontFamily: SharelyFonts.sans,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      pageTransitionsTheme: _pageTransitions,
    );
  }
}

const _snackBarTheme = SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor: SharelyColors.elevated,
  contentTextStyle: TextStyle(
    fontFamily: SharelyFonts.sans,
    fontSize: 14,
    color: SharelyColors.text,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(SharelyRadii.button),
    side: BorderSide(color: SharelyColors.lineStrong),
  ),
);

CheckboxThemeData _checkboxTheme() => CheckboxThemeData(
  fillColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? SharelyColors.primary
        : Colors.transparent,
  ),
  checkColor: const WidgetStatePropertyAll(SharelyColors.onPrimary),
  side: const BorderSide(color: SharelyColors.lineStrong, width: 1.5),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  ),
);

const _bottomSheetTheme = BottomSheetThemeData(
  backgroundColor: SharelyColors.surface,
  modalBarrierColor: SharelyColors.scrim,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: SharelyRadii.card),
    side: BorderSide(color: SharelyColors.lineStrong),
  ),
);

const _dialogTheme = DialogThemeData(
  backgroundColor: SharelyColors.surface,
  barrierColor: SharelyColors.scrim,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(SharelyRadii.card),
    side: BorderSide(color: SharelyColors.lineStrong),
  ),
);

const _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

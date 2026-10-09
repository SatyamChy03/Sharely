import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// The design's text input: canvas fill, strong hairline, cyan when focused.
InputDecoration sharelyInputDecoration({String? hintText, Widget? prefixIcon}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(SharelyRadii.button),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: SharelyColors.textSecondary),
    prefixIcon: prefixIcon,
    prefixIconColor: SharelyColors.textSecondary,
    filled: true,
    fillColor: SharelyColors.background,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: border(SharelyColors.lineStrong),
    focusedBorder: border(SharelyColors.primary),
    border: border(SharelyColors.lineStrong),
  );
}

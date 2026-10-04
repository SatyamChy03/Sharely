import 'package:flutter/material.dart';

/// Colour tokens from the locked v2 design. Never use raw hex in widgets.
abstract final class SharelyColors {
  static const ink = Color(0xFF112D4E);
  static const accent = Color(0xFF3F72AF);
  static const onAccent = Color(0xFFFFFFFF);
  // Accent tint for text and lines on ink, where plain accent is too faint.
  static const accentOnInk = Color(0xFF8FB4E3);
  static const mist = Color(0xFFDBE2EF);
  static const paper = Color(0xFFF9F7F7);
  static const slate = Color(0xFF4D6585);
  static const surface = Color(0xFFFFFFFF);
  static const paperBorder = Color(0xFFDBE2EF);

  // Dark-screen layers: tints of ink so the palette stays four colours.
  static const inkRaised = Color(0xFF1A3A60);
  static const inkRaisedHigh = Color(0xFF21466F);
  static const inkBorder = Color(0xFF1F3D63);
  static const inkBorderStrong = Color(0xFF2B4D78);
  static const onInkMuted = Color(0xFF9DB0C8);
  static const onInkSoft = Color(0xFFDBE2EF);
}

abstract final class SharelySpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class SharelyRadii {
  static const chip = Radius.circular(999);
  static const button = Radius.circular(18);
  static const tile = Radius.circular(22);
  static const card = Radius.circular(28);
  static const panel = Radius.circular(32);
}

abstract final class SharelySizes {
  static const double minTouchTarget = 44;
  static const double buttonHeight = 60;
}

abstract final class SharelyMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const transferLoop = Duration(milliseconds: 2400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Easing.emphasizedDecelerate;
}

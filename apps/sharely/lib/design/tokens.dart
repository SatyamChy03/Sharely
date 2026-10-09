import 'package:flutter/material.dart';

/// Colour tokens from the v3 design system. Never use raw hex in widgets.
abstract final class SharelyColors {
  static const background = Color(0xFF071A2D);
  static const surface = Color(0xFF0D2742);
  static const elevated = Color(0xFF123556);
  // A step below surface, for rows and wells that sit inside a card.
  static const sunken = Color(0xFF0A2139);
  static const line = Color(0xFF1B3F63);
  static const lineStrong = Color(0xFF24507A);
  static const lineHover = Color(0xFF2E6390);
  static const secondaryHover = Color(0xFF174068);

  // Cyan marks actions, progress, connection and selected navigation only.
  static const primary = Color(0xFF71C9CE);
  static const primaryHover = Color(0xFF8DE0E4);
  static const primarySoft = Color(0xFFA6E3E9);
  static const onPrimary = Color(0xFF071A2D);

  static const text = Color(0xFFF5FAFC);
  static const textSecondary = Color(0xFF91A9BA);

  static const success = Color(0xFF52D273);
  static const danger = Color(0xFFFF647C);
  static const dangerText = Color(0xFFFF8A9C);
  static const dangerSurface = Color(0xFF2A1F35);
  static const dangerLine = Color(0xFF7A3445);
  static const stalled = Color(0xFF5E7A90);

  static const primaryTint = Color(0x1F71C9CE);
  static const successTint = Color(0x1F52D273);
  static const dangerTint = Color(0x1FFF647C);
  static const neutralTint = Color(0x1A91A9BA);
  static const scrim = Color(0xB8030C16);
  static const shadow = Color(0x59020A14);
}

abstract final class SharelySpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double page = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Smaller things get smaller corners.
abstract final class SharelyRadii {
  static const pill = Radius.circular(999);
  static const badge = Radius.circular(6);
  static const row = Radius.circular(8);
  static const button = Radius.circular(10);
  static const tile = Radius.circular(12);
  static const zone = Radius.circular(16);
  static const card = Radius.circular(20);
}

abstract final class SharelySizes {
  static const double minTouchTarget = 44;
  static const double buttonLarge = 52;
  static const double buttonMedium = 44;
  static const double buttonSmall = 36;
  static const double sidebarWidth = 240;
  static const double tabBarHeight = 66;
}

abstract final class SharelyMotion {
  static const fast = Duration(milliseconds: 140);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const transferLoop = Duration(milliseconds: 1800);

  static const Curve standard = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve emphasized = Cubic(0.2, 0.8, 0.2, 1);
}

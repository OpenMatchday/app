import 'package:flutter/material.dart';

/// Product UI brand tokens mirrored from OpenMatchday/design
/// `tokens/brand.tokens.v0.json` (design_tokens_version 0.1.0).
/// Sources: PROJECT_SPEC AC-12.1; WCAG 2.2 SC 1.4.3.
class BrandTokens {
  const BrandTokens._();

  static const String designTokensVersion = '0.1.0';
  static const String identity = 'pitch-side control room';

  static const int spacingUnitPx = 8;

  static const Color directorBg = Color(0xFF0F1412);
  static const Color directorSurface = Color(0xFF13261F);
  static const Color directorSurfaceRaised = Color(0xFF1A2A22);
  static const Color directorBorder = Color(0xFF2A3832);
  static const Color directorBorderActive = Color(0xFF3D8B6E);
  static const Color directorText = Color(0xFFE8EDE9);
  static const Color directorTextMuted = Color(0xFF9BB0A4);
  static const Color directorAccent = Color(0xFF3D8B6E);
  static const Color directorAccentPressed = Color(0xFF2F6B55);
  static const Color directorWarning = Color(0xFFE8C547);
  static const Color directorDanger = Color(0xFF8B3D3D);
  static const Color directorFocus = Color(0xFF7EC8A8);

  static const Color cameraBg = Color(0xFFDDE6E0);
  static const Color cameraSurface = Color(0xFFF2F5F3);
  static const Color cameraSurfaceRaised = Color(0xFFFFFFFF);
  static const Color cameraBorder = Color(0xFFA8B8B0);
  static const Color cameraBorderActive = Color(0xFF1B4D3E);
  static const Color cameraText = Color(0xFF1A2420);
  static const Color cameraTextMuted = Color(0xFF4A5C54);
  static const Color cameraAccent = Color(0xFF1B4D3E);
  static const Color cameraAccentPressed = Color(0xFF143B30);
  static const Color cameraFocus = Color(0xFF1B4D3E);

  static const Color tallyOnAirBg = Color(0xFFB00020);
  static const Color tallyOnAirBorder = Color(0xFFFF4D4D);
  static const Color tallyOnAirText = Color(0xFFFFFFFF);
  static const Color tallyOffBg = Color(0xFF1A2420);
  static const Color tallyOffBorder = Color(0xFF2A3832);
  static const Color tallyOffText = Color(0xFF9BB0A4);
  static const double tallyMinHeightPx = 88;
  static const String tallyLabelOn = 'ON AIR';
  static const String tallyLabelOff = 'TALLY OFF';

  /// Seed retained for Material ColorScheme generation (legacy seed).
  static const Color materialSeed = Color(0xFF1B4D3E);
}

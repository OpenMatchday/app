import 'package:flutter/material.dart';

import 'brand_tokens.dart';

/// Dark director ThemeData from brand tokens (AC-12.1).
ThemeData openMatchdayDirectorTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: BrandTokens.materialSeed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base.copyWith(
      surface: BrandTokens.directorSurface,
      onSurface: BrandTokens.directorText,
      primary: BrandTokens.directorAccent,
      onPrimary: BrandTokens.directorText,
      secondary: BrandTokens.directorAccentPressed,
      error: BrandTokens.directorDanger,
      outline: BrandTokens.directorBorder,
    ),
    scaffoldBackgroundColor: BrandTokens.directorBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: BrandTokens.directorSurface,
      foregroundColor: BrandTokens.directorText,
      elevation: 0,
    ),
    dividerColor: BrandTokens.directorBorder,
    focusColor: BrandTokens.directorFocus,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: BrandTokens.directorText),
      bodySmall: TextStyle(color: BrandTokens.directorTextMuted),
      titleMedium: TextStyle(color: BrandTokens.directorText),
      headlineSmall: TextStyle(
        color: BrandTokens.directorText,
        letterSpacing: -0.3,
      ),
    ),
  );
}

/// Daylight camera control ThemeData from brand tokens (AC-12.1).
ThemeData openMatchdayCameraDaylightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: BrandTokens.cameraAccent,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: base.copyWith(
      surface: BrandTokens.cameraSurface,
      onSurface: BrandTokens.cameraText,
      primary: BrandTokens.cameraAccent,
      onPrimary: BrandTokens.cameraSurfaceRaised,
      secondary: BrandTokens.cameraAccentPressed,
      error: BrandTokens.directorDanger,
      outline: BrandTokens.cameraBorder,
    ),
    scaffoldBackgroundColor: BrandTokens.cameraBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: BrandTokens.cameraSurface,
      foregroundColor: BrandTokens.cameraText,
      elevation: 0,
    ),
    dividerColor: BrandTokens.cameraBorder,
    focusColor: BrandTokens.cameraFocus,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: BrandTokens.cameraText),
      bodySmall: TextStyle(color: BrandTokens.cameraTextMuted),
      titleMedium: TextStyle(color: BrandTokens.cameraText),
      headlineSmall: TextStyle(
        color: BrandTokens.cameraText,
        letterSpacing: -0.3,
      ),
    ),
  );
}

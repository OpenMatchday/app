import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/design/brand_tokens.dart';
import 'package:open_matchday/design/open_matchday_theme.dart';
import 'package:open_matchday/main.dart';

void main() {
  test('brand tokens match design system hex values', () {
    expect(BrandTokens.designTokensVersion, '0.1.0');
    expect(BrandTokens.directorBg, const Color(0xFF0F1412));
    expect(BrandTokens.directorAccent, const Color(0xFF3D8B6E));
    expect(BrandTokens.cameraAccent, const Color(0xFF1B4D3E));
    expect(BrandTokens.tallyOnAirBg, const Color(0xFFB00020));
    expect(BrandTokens.tallyOnAirBorder, const Color(0xFFFF4D4D));
    expect(BrandTokens.tallyMinHeightPx, 88);
    expect(BrandTokens.tallyLabelOn, 'ON AIR');
    expect(BrandTokens.tallyOnAirBg, isNot(BrandTokens.directorAccent));
  });

  test('banned purple palette hexes are absent from brand tokens', () {
    final values = <Color>[
      BrandTokens.directorBg,
      BrandTokens.directorSurface,
      BrandTokens.directorAccent,
      BrandTokens.cameraBg,
      BrandTokens.cameraAccent,
      BrandTokens.tallyOnAirBg,
      BrandTokens.materialSeed,
    ];
    const banned = <int>[
      0xFF7C3AED,
      0xFF8B5CF6,
      0xFFA855F7,
      0xFF6366F1,
      0xFF4F46E5,
    ];
    for (final color in values) {
      expect(banned.contains(color.toARGB32()), isFalse);
    }
  });

  test('director theme uses dark brand surfaces', () {
    final theme = openMatchdayDirectorTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, BrandTokens.directorBg);
    expect(theme.colorScheme.primary, BrandTokens.directorAccent);
  });

  test('camera daylight theme uses light control plane', () {
    final theme = openMatchdayCameraDaylightTheme();
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, BrandTokens.cameraBg);
    expect(theme.colorScheme.primary, BrandTokens.cameraAccent);
  });

  testWidgets('app root uses director theme', (tester) async {
    await tester.pumpWidget(const OpenMatchdayApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, BrandTokens.directorBg);
  });
}

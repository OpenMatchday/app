import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/calibration/geometry.dart';
import 'package:open_matchday/calibration/regions.dart';

void main() {
  const frameW = 1280.0;
  const frameH = 720.0;

  CornerSet sampleCorners() {
    return const CornerSet(
      tl: CalibPoint(frameW * 0.18, frameH * 0.22),
      tr: CalibPoint(frameW * 0.82, frameH * 0.18),
      br: CalibPoint(frameW * 0.88, frameH * 0.78),
      bl: CalibPoint(frameW * 0.14, frameH * 0.72),
    );
  }

  test('AC-4.3 accepts convex TL-TR-BR-BL order', () {
    final result = validateCorners(
      sampleCorners(),
      frameWidth: frameW,
      frameHeight: frameH,
    );
    expect(result.ok, isTrue);
    expect(result.winding, 'ccw');
  });

  test('AC-4.3 rejects crossed bowtie corners', () {
    const bad = CornerSet(
      tl: CalibPoint(100, 100),
      tr: CalibPoint(500, 100),
      br: CalibPoint(100, 400),
      bl: CalibPoint(500, 400),
    );
    final result = validateCorners(
      bad,
      frameWidth: frameW,
      frameHeight: frameH,
    );
    expect(result.ok, isFalse);
    expect(result.reasons, contains('not_convex_or_crossed'));
  });

  test('AC-4.3 rejects undersized area', () {
    const tiny = CornerSet(
      tl: CalibPoint(640, 360),
      tr: CalibPoint(650, 360),
      br: CalibPoint(650, 370),
      bl: CalibPoint(640, 370),
    );
    final result = validateCorners(
      tiny,
      frameWidth: frameW,
      frameHeight: frameH,
    );
    expect(result.ok, isFalse);
    expect(result.reasons, contains('area_below_minimum'));
  });

  test('AC-4.4 maps corners to unit board via homography', () {
    final corners = sampleCorners();
    final h = boardHomography(corners);
    final mapped = corners.ordered().map((p) => applyHomography(h, p)).toList();
    expect(mapped[0].x, closeTo(0, 1e-6));
    expect(mapped[0].y, closeTo(0, 1e-6));
    expect(mapped[1].x, closeTo(1, 1e-6));
    expect(mapped[1].y, closeTo(0, 1e-6));
    expect(mapped[2].x, closeTo(1, 1e-6));
    expect(mapped[2].y, closeTo(1, 1e-6));
    expect(mapped[3].x, closeTo(0, 1e-6));
    expect(mapped[3].y, closeTo(1, 1e-6));
  });

  test('AC-4.5 omits shot_clock for basketball youth and futsal', () {
    expect(fieldsForSport('basketball/youth'), isNot(contains('shot_clock')));
    expect(fieldsForSport('futsal/fifa'), isNot(contains('shot_clock')));
    expect(fieldsForSport('basketball/fiba'), contains('shot_clock'));
    final youth = defaultRegionsForSport('basketball/youth');
    expect(youth.any((r) => r.fieldId == 'shot_clock'), isFalse);
    expect(validateRegions(youth, sportId: 'basketball/youth').ok, isTrue);
  });

  test('AC-4.5 rejects faked fields absent from sport', () {
    final regions = <BoardRegion>[
      ...defaultRegionsForSport('futsal/fifa'),
      const BoardRegion(fieldId: 'shot_clock', x: 0.4, y: 0.4, w: 0.1, h: 0.1),
    ];
    final result = validateRegions(regions, sportId: 'futsal/fifa');
    expect(result.ok, isFalse);
    expect(result.reasons.first, contains('field_not_in_sport:shot_clock'));
  });

  test('AC-4.6 survives scale and rotation via normalized corners', () {
    final corners = sampleCorners();
    final normalized = normalizeCorners(
      corners,
      width: frameW,
      height: frameH,
    );
    final scaled = mapNormalizedCornersToDisplay(
      normalized,
      displayWidth: 1920,
      displayHeight: 1080,
    );
    final h = boardHomography(scaled);
    final mapped = applyHomography(h, scaled.tl);
    expect(mapped.x, closeTo(0, 1e-6));
    expect(mapped.y, closeTo(0, 1e-6));

    final rotated = mapNormalizedCornersToDisplay(
      normalized,
      displayWidth: 720,
      displayHeight: 1280,
      rotationDegrees: 90,
    );
    final rh = boardHomography(rotated);
    final rm = applyHomography(rh, rotated.br);
    expect(rm.x, closeTo(1, 1e-6));
    expect(rm.y, closeTo(1, 1e-6));
  });
}

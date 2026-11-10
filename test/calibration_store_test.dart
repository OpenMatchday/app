import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/calibration/calibration_store.dart';
import 'package:open_matchday/calibration/geometry.dart';
import 'package:open_matchday/calibration/regions.dart';

void main() {
  CornerSet sample() {
    return const CornerSet(
      tl: CalibPoint(230.4, 158.4),
      tr: CalibPoint(1049.6, 129.6),
      br: CalibPoint(1126.4, 561.6),
      bl: CalibPoint(179.2, 518.4),
    );
  }

  test('AC-4.1 freeze moves to frozen phase', () {
    final store = CalibrationStore(clockMs: () => 42);
    expect(store.phase, CalibrationPhase.live);
    final result = store.freezeFrame();
    expect(result.ok, isTrue);
    expect(store.phase, CalibrationPhase.frozen);
    expect(store.freezeId, 'freeze-42');
  });

  test('AC-4.2 refuses corners before freeze', () {
    final store = CalibrationStore();
    final refused = store.setCornerPixel('tl', const CalibPoint(10, 10));
    expect(refused.ok, isFalse);
    expect(refused.message, contains('freeze'));
  });

  test('AC-4.2–4.4 freeze, mark, validate, rectify, confirm', () {
    final store = CalibrationStore(clockMs: () => 1);
    store.freezeFrame();
    store.setZoom(2);
    expect(store.zoom, 2);
    for (final id in cornerOrder) {
      store.selectCorner(id);
    }
    final set = store.setAllCorners(sample());
    expect(set.ok, isTrue);
    final computed = store.computeRectified();
    expect(computed.ok, isTrue);
    expect(store.phase, CalibrationPhase.rectifiedPending);
    expect(store.homography, isNotNull);
    final confirmed = store.confirmGeometry();
    expect(confirmed.ok, isTrue);
    expect(store.geometryAccepted, isTrue);
  });

  test('AC-4.4 redo clears accept and returns to corners', () {
    final store = CalibrationStore();
    store.freezeFrame();
    store.setAllCorners(sample());
    store.computeRectified();
    store.confirmGeometry();
    final redo = store.redoCorners();
    expect(redo.ok, isTrue);
    expect(store.geometryAccepted, isFalse);
    expect(store.phase, CalibrationPhase.corners);
  });

  test('AC-4.5 regions after confirm; youth omits shot_clock', () {
    final store = CalibrationStore(sportId: 'basketball/youth');
    store.freezeFrame();
    store.setAllCorners(sample());
    store.computeRectified();
    store.confirmGeometry();
    final begun = store.beginRegions();
    expect(begun.ok, isTrue);
    expect(store.availableFields, isNot(contains('shot_clock')));
    expect(
      store.regions.any((r) => r.fieldId == 'shot_clock'),
      isFalse,
    );
    final faked = store.upsertRegion(
      const BoardRegion(fieldId: 'shot_clock', x: 0.1, y: 0.1, w: 0.1, h: 0.1),
    );
    expect(faked.ok, isFalse);
    expect(faked.message, contains('absent'));
    final done = store.completeRegions();
    expect(done.ok, isTrue);
    expect(store.phase, CalibrationPhase.complete);
  });

  test('AC-4.6 display transform keeps board mapping', () {
    final store = CalibrationStore();
    store.freezeFrame();
    store.setAllCorners(sample());
    store.computeRectified();
    store.confirmGeometry();
    final rebound = store.applyDisplayTransform(
      displayWidth: 1920,
      displayHeight: 1080,
      rotationDegrees: 0,
    );
    expect(rebound.ok, isTrue);
    final board = store.mapFrameToBoard(store.pixelCorners!.tl);
    expect(board, isNotNull);
    expect(board!.x, closeTo(0, 1e-6));
    expect(board.y, closeTo(0, 1e-6));
  });
}

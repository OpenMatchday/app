import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/calibration/calibration_store.dart';
import 'package:open_matchday/calibration/geometry.dart';
import 'package:open_matchday/calibration/ocr_confidence.dart';
import 'package:open_matchday/calibration/scoreboard_ocr_store.dart';
import 'package:open_matchday/event_operator/authority_store.dart';
import 'package:open_matchday/event_operator/fields.dart';
import 'package:open_matchday/event_operator/ocr_reading.dart';

void _completeCalibration(CalibrationStore store) {
  store.freezeFrame(width: 1280, height: 720);
  store.setAllCorners(
    CornerSet(
      tl: const CalibPoint(200, 150),
      tr: const CalibPoint(1000, 140),
      br: const CalibPoint(1050, 560),
      bl: const CalibPoint(180, 540),
    ),
  );
  expect(store.computeRectified().ok, isTrue);
  expect(store.confirmGeometry().ok, isTrue);
  expect(store.beginRegions().ok, isTrue);
  expect(store.completeRegions().ok, isTrue);
}

void main() {
  test('readings carry value confidence timestamp staleness', () {
    final store = ScoreboardOcrStore(
      now: () => DateTime.utc(2026, 11, 10, 20),
    );
    final reading = store.readingFromRaw(
      field: ScoreField.homeScore,
      rawText: '78',
      value: 78,
    );
    expect(reading.confidence, 1.0);
    expect(reading.capturedAt.toIso8601String(), '2026-11-10T20:00:00.000Z');
    expect(reading.stale, isFalse);
    store.ingestReading(reading);
    expect(store.readings.single.toWire()['stale'], isFalse);
  });

  test('camera move marks readings and live crops stale and requires recalibration',
      () {
    final calibration = CalibrationStore();
    _completeCalibration(calibration);
    final store = ScoreboardOcrStore(calibration: calibration);
    store.setMoveThreshold(15.6172);
    store.ingestReading(
      store.readingFromRaw(
        field: ScoreField.clock,
        rawText: '09:42',
        value: '09:42',
      ),
    );

    final moved = store.probeMoveMad(31.2344);
    expect(moved.ok, isTrue);
    expect(store.recalibrationRequired, isTrue);
    expect(store.liveCropsStale, isTrue);
    expect(store.readingsStale, isTrue);
    expect(store.trustOcr, isFalse);
    expect(store.trustLiveCrops, isFalse);
    expect(store.readings.every((r) => r.stale), isTrue);
  });

  test('recalibration required before trusting new OCR or crops', () {
    final calibration = CalibrationStore();
    _completeCalibration(calibration);
    final store = ScoreboardOcrStore(calibration: calibration);
    store.markCameraMoved(mad: 40);
    final blocked = store.clearAfterRecalibration();
    expect(blocked.ok, isFalse);

    calibration.redoCorners();
    _completeCalibration(calibration);
    final cleared = store.clearAfterRecalibration();
    expect(cleared.ok, isTrue);
    expect(store.recalibrationRequired, isFalse);
    expect(store.trustOcr, isTrue);
    expect(store.trustLiveCrops, isTrue);
  });

  test('low-confidence OCR never overrides confirmed state via store', () {
    final calibration = CalibrationStore();
    _completeCalibration(calibration);
    final ocr = ScoreboardOcrStore(calibration: calibration);
    final authority = AuthorityStore(minConfidence: calibratedMinConfidence);
    authority.setField(
      commandId: 'set',
      field: ScoreField.homeScore,
      value: 5,
      authority: FieldAuthority.ocrAssisted,
    );
    authority.confirmField(
      commandId: 'confirm',
      field: ScoreField.homeScore,
      action: ConfirmAction.confirm,
    );

    final low = OcrReading(
      field: ScoreField.homeScore,
      value: 99,
      confidence: 0.2,
      capturedAt: DateTime.utc(2026, 11, 10),
      stale: false,
    );
    final result = ocr.applyToAuthority(
      authority: authority,
      commandId: 'ocr-low',
      reading: low,
    );
    expect(result, isNotNull);
    expect(result!.applied, isFalse);
    expect(authority.fieldState(ScoreField.homeScore).value, 5);
  });

  test('stale OCR is not applied to authority while recalibration required', () {
    final calibration = CalibrationStore();
    _completeCalibration(calibration);
    final ocr = ScoreboardOcrStore(calibration: calibration);
    final authority = AuthorityStore();
    authority.setField(
      commandId: 'set',
      field: ScoreField.awayScore,
      value: 1,
      authority: FieldAuthority.ocrAssisted,
    );
    ocr.markCameraMoved();
    final reading = ocr.readingFromRaw(
      field: ScoreField.awayScore,
      rawText: '65',
      value: 65,
    );
    expect(reading.stale, isTrue);
    final result = ocr.applyToAuthority(
      authority: authority,
      commandId: 'ocr-stale',
      reading: reading,
    );
    expect(result, isNull);
    expect(authority.fieldState(ScoreField.awayScore).value, 1);
  });
}

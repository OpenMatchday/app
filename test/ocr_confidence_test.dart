import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/calibration/ocr_confidence.dart';

void main() {
  test('digit parse quality scores clean clock and scores high', () {
    expect(digitParseQuality('09:42', 'clock'), 1.0);
    expect(digitParseQuality('78', 'home_score'), 1.0);
    expect(digitParseQuality('', 'home_score'), 0.0);
  });

  test('calibrateConfidence prefers TSV conf when greater than zero', () {
    final calibrated = calibrateConfidence(
      rawText: '24',
      fieldId: 'shot_clock',
      meanWordConf: 91,
    );
    expect(calibrated.signal, 'tesseract_tsv_conf');
    expect(calibrated.confidence, closeTo(0.91, 1e-9));
  });

  test('calibrateConfidence falls back to digit parse when TSV conf is zero', () {
    final calibrated = calibrateConfidence(
      rawText: '65',
      fieldId: 'away_score',
      meanWordConf: 0,
    );
    expect(calibrated.signal, 'digit_parse_quality');
    expect(calibrated.confidence, 1.0);
    expect(calibrated.confidence, greaterThanOrEqualTo(calibratedMinConfidence));
  });

  test('empty parse stays below calibrated authority gate', () {
    final calibrated = calibrateConfidence(
      rawText: '',
      fieldId: 'period',
      meanWordConf: 0,
    );
    expect(calibrated.confidence, lessThan(calibratedMinConfidence));
  });
}

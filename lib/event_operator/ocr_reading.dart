import 'fields.dart';

/// OCR reading shape (AC-5.2): value, confidence, timestamp, staleness.
class OcrReading {
  const OcrReading({
    required this.field,
    required this.value,
    required this.confidence,
    required this.capturedAt,
    required this.stale,
  });

  final ScoreField field;
  final Object value;

  /// 0.0–1.0 inclusive. Calibrated in OM-031 (TSV conf/100 or digit-parse).
  final double confidence;
  final DateTime capturedAt;
  final bool stale;

  Map<String, Object> toWire() => <String, Object>{
        'field': field.wire,
        'value': value,
        'confidence': confidence,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'stale': stale,
      };
}

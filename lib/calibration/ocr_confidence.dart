/// OCR confidence calibration (OM-031 / AC-5.2, AC-5.4).
///
/// Prefers Tesseract TSV word conf/100 when > 0; else digit-parse quality.
/// Mirrors media/ocr/confidence.py. Gate [minConfidence] stays 0.7.
library;

/// Authority low-confidence gate (AC-5.4). Calibrated against digit-parse
/// fixtures where clean reads score 1.0 and empty/noise score below this.
const double calibratedMinConfidence = 0.7;

String normalizeOcrText(String text) {
  return text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String digitsOnly(String text) {
  return text.replaceAll(RegExp(r'[^0-9:]'), '');
}

double digitParseQuality(String raw, String fieldId) {
  final text = normalizeOcrText(raw);
  if (text.isEmpty) {
    return 0;
  }
  final cleaned = digitsOnly(text);
  if (cleaned.isEmpty) {
    return 0;
  }
  if (fieldId == 'clock') {
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(cleaned)) {
      return 1;
    }
    if (cleaned.contains(':') && RegExp(r'\d').hasMatch(cleaned)) {
      return 0.45;
    }
    return 0.2;
  }
  if (RegExp(r'^\d{1,3}$').hasMatch(cleaned) &&
      cleaned == text.replaceAll(' ', '')) {
    return 1;
  }
  if (RegExp(r'^\d{1,3}$').hasMatch(cleaned)) {
    return 0.85;
  }
  if (RegExp(r'\d').hasMatch(cleaned)) {
    return 0.4;
  }
  return 0;
}

class CalibratedConfidence {
  const CalibratedConfidence({
    required this.confidence,
    required this.signal,
    this.meanWordConf,
    required this.digitParseQualityValue,
  });

  final double confidence;
  final String signal;
  final double? meanWordConf;
  final double digitParseQualityValue;
}

CalibratedConfidence calibrateConfidence({
  required String rawText,
  required String fieldId,
  double? meanWordConf,
}) {
  if (meanWordConf != null && meanWordConf > 0) {
    final conf = (meanWordConf / 100).clamp(0.0, 1.0);
    return CalibratedConfidence(
      confidence: conf,
      signal: 'tesseract_tsv_conf',
      meanWordConf: meanWordConf,
      digitParseQualityValue: digitParseQuality(rawText, fieldId),
    );
  }
  final quality = digitParseQuality(rawText, fieldId);
  return CalibratedConfidence(
    confidence: quality,
    signal: 'digit_parse_quality',
    meanWordConf: meanWordConf,
    digitParseQualityValue: quality,
  );
}

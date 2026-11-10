import '../event_operator/authority_store.dart';
import '../event_operator/fields.dart';
import '../event_operator/ocr_reading.dart';
import 'calibration_store.dart';
import 'ocr_confidence.dart';

class ScoreboardOcrActionResult {
  const ScoreboardOcrActionResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

/// Scoreboard Reader OCR + camera-move stale path (OM-031 / AC-4.7, AC-5.2).
class ScoreboardOcrStore {
  ScoreboardOcrStore({
    CalibrationStore? calibration,
    this.minConfidence = calibratedMinConfidence,
    DateTime Function()? now,
  })  : calibration = calibration ?? CalibrationStore(),
        _now = now ?? DateTime.now;

  final CalibrationStore calibration;
  final double minConfidence;
  final DateTime Function() _now;

  final List<OcrReading> _readings = <OcrReading>[];
  bool _recalibrationRequired = false;
  bool _liveCropsStale = false;
  bool _readingsStale = false;
  double? _moveThreshold;
  double? _lastMoveMad;

  List<OcrReading> get readings => List<OcrReading>.unmodifiable(_readings);

  bool get recalibrationRequired => _recalibrationRequired;

  bool get liveCropsStale => _liveCropsStale;

  bool get readingsStale => _readingsStale;

  double? get moveThreshold => _moveThreshold;

  double? get lastMoveMad => _lastMoveMad;

  bool get trustOcr =>
      !_recalibrationRequired &&
      !_readingsStale &&
      calibration.phase == CalibrationPhase.complete;

  bool get trustLiveCrops =>
      !_recalibrationRequired &&
      !_liveCropsStale &&
      calibration.geometryAccepted;

  void setMoveThreshold(double threshold) {
    _moveThreshold = threshold;
  }

  /// Ingest a media-plane reading; force stale when recalibration is required.
  ScoreboardOcrActionResult ingestReading(OcrReading reading) {
    final forcedStale = _recalibrationRequired || _readingsStale || reading.stale;
    final next = OcrReading(
      field: reading.field,
      value: reading.value,
      confidence: reading.confidence,
      capturedAt: reading.capturedAt,
      stale: forcedStale,
    );
    _readings.removeWhere((row) => row.field == next.field);
    _readings.add(next);
    return ScoreboardOcrActionResult(
      ok: true,
      message: forcedStale
          ? 'stale reading stored for ${next.field.wire}'
          : 'reading stored for ${next.field.wire}',
    );
  }

  /// Build a calibrated reading from raw OCR text (AC-5.2).
  OcrReading readingFromRaw({
    required ScoreField field,
    required String rawText,
    Object? value,
    double? meanWordConf,
    bool stale = false,
  }) {
    final calibrated = calibrateConfidence(
      rawText: rawText,
      fieldId: field.wire,
      meanWordConf: meanWordConf,
    );
    return OcrReading(
      field: field,
      value: value ?? rawText,
      confidence: calibrated.confidence,
      capturedAt: _now().toUtc(),
      stale: stale || _recalibrationRequired || _readingsStale,
    );
  }

  /// AC-4.7: camera move marks readings + live crops stale; request recalibration.
  ScoreboardOcrActionResult markCameraMoved({double? mad}) {
    _lastMoveMad = mad;
    _recalibrationRequired = true;
    _liveCropsStale = true;
    _readingsStale = true;
    calibration.invalidateForCameraMove();
    final marked = <OcrReading>[
      for (final reading in _readings)
        OcrReading(
          field: reading.field,
          value: reading.value,
          confidence: reading.confidence,
          capturedAt: reading.capturedAt,
          stale: true,
        ),
    ];
    _readings
      ..clear()
      ..addAll(marked);
    return const ScoreboardOcrActionResult(
      ok: true,
      message: 'camera move detected; recalibration required',
    );
  }

  /// Probe helper: MAD above threshold triggers [markCameraMoved].
  ScoreboardOcrActionResult probeMoveMad(double mad) {
    final threshold = _moveThreshold;
    if (threshold == null) {
      return const ScoreboardOcrActionResult(
        ok: false,
        message: 'move threshold not set',
      );
    }
    _lastMoveMad = mad;
    if (mad > threshold) {
      return markCameraMoved(mad: mad);
    }
    return ScoreboardOcrActionResult(
      ok: true,
      message: 'geometry stable (mad=$mad <= $threshold)',
    );
  }

  /// After operator completes recalibration (freeze → corners → regions).
  ScoreboardOcrActionResult clearAfterRecalibration() {
    if (calibration.phase != CalibrationPhase.complete) {
      return ScoreboardOcrActionResult(
        ok: false,
        message: 'complete recalibration before clearing stale state '
            '(phase=${calibration.phase.name})',
      );
    }
    _recalibrationRequired = false;
    _liveCropsStale = false;
    _readingsStale = false;
    _readings.clear();
    return const ScoreboardOcrActionResult(
      ok: true,
      message: 'recalibration accepted; OCR and live crops trusted again',
    );
  }

  /// Apply trusted high-confidence readings into authority (AC-5.4).
  CommandResult? applyToAuthority({
    required AuthorityStore authority,
    required String commandId,
    required OcrReading reading,
  }) {
    if (!trustOcr || reading.stale) {
      return null;
    }
    return authority.applyOcrReading(commandId: commandId, reading: reading);
  }
}

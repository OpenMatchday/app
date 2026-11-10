// A/V sync monitor and drift correction state (AC-2.6 / G5).
// Offset is audio relative to video in milliseconds (positive = audio late).
// Product pass/fail uses measured media-gate numbers only.

class AvSyncSample {
  const AvSyncSample({
    required this.offsetMs,
    required this.measuredAtMs,
    this.corrected = false,
    this.residualMs,
  });

  final double offsetMs;
  final int measuredAtMs;
  final bool corrected;
  final double? residualMs;
}

class AvSyncMonitor {
  AvSyncMonitor({
    this.offsetMs,
    this.correctionMs = 0,
    this.lastMeasuredAtMs,
    this.message = '',
    List<AvSyncSample>? history,
  }) : history = history ?? <AvSyncSample>[];

  /// Latest measured audio-video offset (ms). Null until first read.
  double? offsetMs;

  /// Applied drift correction (ms). Positive advances late audio / delays video.
  double correctionMs;

  int? lastMeasuredAtMs;
  String message;
  List<AvSyncSample> history;

  bool get hasReading => offsetMs != null;

  void recordSample({
    required double offsetMs,
    required int measuredAtMs,
    bool corrected = false,
    double? residualMs,
  }) {
    this.offsetMs = offsetMs;
    lastMeasuredAtMs = measuredAtMs;
    history = [
      ...history,
      AvSyncSample(
        offsetMs: offsetMs,
        measuredAtMs: measuredAtMs,
        corrected: corrected,
        residualMs: residualMs,
      ),
    ];
  }

  void applyCorrection(double correctionMs) {
    this.correctionMs = correctionMs;
  }
}

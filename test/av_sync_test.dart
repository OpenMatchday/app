import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/av_sync.dart';

void main() {
  test('AvSyncMonitor records offset and applies correction', () {
    final monitor = AvSyncMonitor();
    expect(monitor.hasReading, isFalse);

    monitor.recordSample(offsetMs: 80, measuredAtMs: 1000);
    expect(monitor.hasReading, isTrue);
    expect(monitor.offsetMs, 80);
    expect(monitor.history, hasLength(1));

    monitor.applyCorrection(80);
    expect(monitor.correctionMs, 80);

    monitor.recordSample(
      offsetMs: 0,
      measuredAtMs: 1100,
      corrected: true,
      residualMs: 0,
    );
    expect(monitor.offsetMs, 0);
    expect(monitor.history.last.corrected, isTrue);
    expect(monitor.history.last.residualMs, 0);
  });
}

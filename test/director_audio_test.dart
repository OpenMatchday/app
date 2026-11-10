import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/audio.dart';
import 'package:open_matchday/director/buses.dart';

void main() {
  test('audio selection is independent of program video source', () {
    final buses = DirectorBuses(programSourceId: 'cam-1');
    buses.audio.selectSource('aud-2');

    expect(buses.programSourceId, 'cam-1');
    expect(buses.audio.selectedSourceId, 'aud-2');
    expect(buses.audio.hasIndependentSelection, isTrue);
    expect(buses.cameraSourceIds, ['cam-1', 'cam-2']);
  });

  test('meters expose peak and rms fields', () {
    const meters = AudioMeters(peakDb: -18.1, rmsDb: -24.2, sourceId: 'aud-1');
    expect(meters.hasLevels, isTrue);
    expect(meters.peakDb, -18.1);
    expect(meters.rmsDb, -24.2);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/buses.dart';
import 'package:open_matchday/director/cut_take.dart';

void main() {
  test('Cut sets Program from Preview without auto-follow beforehand', () {
    final buses = DirectorBuses(
      preview: const PreviewSourceStatus(
        state: PreviewSourceState.receiving,
        medium: 'wifi',
        sourceId: 'cam-2',
      ),
    );
    expect(buses.programSourceId, isEmpty);
    expect(buses.programFeedsOutputs, isFalse);

    final result = buses.cutTake(action: CutTakeAction.cut, previewSourceId: 'cam-2');
    expect(result.action, CutTakeAction.cut);
    expect(result.previousProgramSourceId, isEmpty);
    expect(result.programSourceId, 'cam-2');
    expect(buses.programSourceId, 'cam-2');
    expect(buses.programFeedsOutputs, isTrue);
    expect(result.cutLatencyMs, greaterThanOrEqualTo(0));
  });

  test('Take switches Program from previous source explicitly', () {
    final buses = DirectorBuses(
      programSourceId: 'cam-1',
      preview: const PreviewSourceStatus(
        state: PreviewSourceState.receiving,
        medium: 'wifi',
        sourceId: 'cam-2',
      ),
    );
    final result = buses.cutTake(action: CutTakeAction.take, previewSourceId: 'cam-2');
    expect(result.action, CutTakeAction.take);
    expect(result.previousProgramSourceId, 'cam-1');
    expect(result.programSourceId, 'cam-2');
    expect(buses.lastCutTake?.programSourceId, 'cam-2');
  });

  test('Cut/Take refuses empty Preview source', () {
    final buses = DirectorBuses();
    expect(
      () => buses.cutTake(action: CutTakeAction.cut, previewSourceId: ''),
      throwsA(isA<CutTakeException>()),
    );
    expect(buses.programSourceId, isEmpty);
  });

  test('Cut/Take refuses invalid action', () {
    final buses = DirectorBuses();
    expect(
      () => buses.cutTake(action: 'auto', previewSourceId: 'cam-1'),
      throwsA(isA<CutTakeException>()),
    );
  });
}

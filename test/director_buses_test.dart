import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/buses.dart';

void main() {
  test('Program does not feed outputs until a Program source is set', () {
    final buses = DirectorBuses();
    expect(buses.preview.state, PreviewSourceState.idle);
    expect(buses.programSourceId, isEmpty);
    expect(buses.programFeedsOutputs, isFalse);

    buses.preview = const PreviewSourceStatus(
      state: PreviewSourceState.receiving,
      medium: 'wifi',
      sourceId: 'cam-1',
      message: 'receiving',
    );
    expect(buses.preview.isReceiving, isTrue);
    expect(
      buses.programFeedsOutputs,
      isFalse,
      reason: 'Preview must not silently feed outputs (AC-2.1)',
    );
  });

  test('Program feeds outputs only with an explicit Program source id', () {
    final buses = DirectorBuses(programSourceId: 'cam-1');
    expect(buses.programFeedsOutputs, isTrue);
  });
}

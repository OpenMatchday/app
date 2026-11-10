import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/source_health.dart';

void main() {
  test('health board tracks connected degraded lost with timestamps', () {
    final board = SourceHealthBoard();
    board.upsert(
      const SourceHealthEntry(
        sourceId: 'cam-1',
        state: SourceHealthState.connected,
        observedAtMs: 1000,
      ),
    );
    board.upsert(
      const SourceHealthEntry(
        sourceId: 'cam-1',
        state: SourceHealthState.degraded,
        observedAtMs: 1100,
        detail: 'packet loss rising',
      ),
    );
    board.upsert(
      const SourceHealthEntry(
        sourceId: 'cam-2',
        state: SourceHealthState.connected,
        observedAtMs: 1105,
      ),
    );

    expect(board.sources, hasLength(2));
    expect(board.entryFor('cam-1')!.state, SourceHealthState.degraded);
    expect(board.entryFor('cam-1')!.observedAtMs, 1100);
    expect(board.entryFor('cam-2')!.state, SourceHealthState.connected);
  });

  test('source loss freezes Program without killing session', () {
    final board = SourceHealthBoard(
      fallbackMode: ProgramFallbackMode.lastFrameFreeze,
    );
    final result = board.applySourceLoss(
      lostSourceId: 'cam-1',
      programSourceId: 'cam-1',
      observedAtMs: 2000,
    );

    expect(result.sessionAlive, isTrue);
    expect(board.sessionAlive, isTrue);
    expect(result.programSafeState, 'last_frame_freeze');
    expect(result.programSourceId, 'cam-1');
    expect(board.entryFor('cam-1')!.state, SourceHealthState.lost);
    expect(board.entryFor('cam-1')!.observedAtMs, 2000);
  });

  test('source loss can switch to alternate source', () {
    final board = SourceHealthBoard(
      fallbackMode: ProgramFallbackMode.alternateSource,
      alternateSourceId: 'cam-2',
    );
    final result = board.applySourceLoss(
      lostSourceId: 'cam-1',
      programSourceId: 'cam-1',
      observedAtMs: 3000,
    );

    expect(result.sessionAlive, isTrue);
    expect(result.programSafeState, 'alternate_source');
    expect(result.programSourceId, 'cam-2');
  });

  test('slate fallback keeps session alive', () {
    final board = SourceHealthBoard(
      fallbackMode: ProgramFallbackMode.slate,
    );
    final result = board.applySourceLoss(
      lostSourceId: 'cam-1',
      programSourceId: 'cam-1',
      observedAtMs: 4000,
    );

    expect(result.programSafeState, 'slate');
    expect(board.sessionAlive, isTrue);
  });

  test('wire labels match protocol program_fallback enum', () {
    expect(ProgramFallbackMode.lastFrameFreeze.wire, 'last_frame_freeze');
    expect(ProgramFallbackMode.slate.wire, 'slate');
    expect(ProgramFallbackMode.alternateSource.wire, 'alternate_source');
    expect(
      ProgramFallbackModeWire.parse('last_frame_freeze'),
      ProgramFallbackMode.lastFrameFreeze,
    );
  });
}

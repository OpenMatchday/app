import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/capability_matrix.dart';
import 'package:open_matchday/director/output_enablement.dart';

void main() {
  test('16:9 9:16 1:1 support flags default unverified', () {
    const matrix = CapabilityMatrix();
    for (final aspect in outputAspects) {
      expect(
        matrix.aspectSupport(aspect, MatrixPlatform.windows).state,
        CapabilityState.unverified,
      );
    }
    expect(
      matrix.recordingSupport(MatrixPlatform.windows).state,
      CapabilityState.unverified,
    );
  });

  test('release blocks unverified output combination', () {
    final enablement = OutputEnablement(releaseBuild: true);
    expect(
      () => enablement.enable(
        recording: true,
        liveAspects: const ['16:9'],
        platform: MatrixPlatform.windows,
      ),
      throwsA(
        isA<OutputEnablementException>().having(
          (error) => error.reason,
          'reason',
          'combination_gated',
        ),
      ),
    );
  });

  test('release allows measured aspect flags and combination', () {
    final matrix = CapabilityMatrix(
      recordingSupportOverrides: {
        'windows': const CapabilityNote(state: CapabilityState.verified),
      },
      aspectSupportOverrides: {
        'windows:16:9': const CapabilityNote(state: CapabilityState.verified),
        'windows:9:16': const CapabilityNote(
          state: CapabilityState.partial,
          limits: '720p only',
        ),
      },
      outputCombinationOverrides: {
        'windows:recording+16:9+9:16': const CapabilityNote(
          state: CapabilityState.partial,
          limits: 'director class smoke; full rehearsal pending OM-047',
        ),
      },
    );
    final enablement = OutputEnablement(matrix: matrix, releaseBuild: true);
    final result = enablement.enable(
      recording: true,
      liveAspects: const ['9:16', '16:9'],
      platform: MatrixPlatform.windows,
    );
    expect(result.combinationState, CapabilityState.partial);
    expect(result.selection.recording, isTrue);
    expect(result.selection.liveAspects, {'16:9', '9:16'});
    expect(result.selection.streaming, isTrue);
  });

  test('release refuses when aspect flag missing even if combination verified',
      () {
    final matrix = CapabilityMatrix(
      recordingSupportOverrides: {
        'windows': const CapabilityNote(state: CapabilityState.verified),
      },
      aspectSupportOverrides: {
        'windows:16:9': const CapabilityNote(state: CapabilityState.verified),
        // 1:1 left unverified
      },
      outputCombinationOverrides: {
        'windows:recording+16:9+1:1': const CapabilityNote(
          state: CapabilityState.verified,
        ),
      },
    );
    final enablement = OutputEnablement(matrix: matrix, releaseBuild: true);
    expect(
      () => enablement.enable(
        recording: true,
        liveAspects: const ['16:9', '1:1'],
        platform: MatrixPlatform.windows,
      ),
      throwsA(isA<OutputEnablementException>()),
    );
  });

  test('non-release allows unverified combinations for measurement', () {
    final enablement = OutputEnablement(releaseBuild: false);
    final result = enablement.enable(
      recording: true,
      liveAspects: const ['16:9', '9:16', '1:1'],
      platform: MatrixPlatform.linux,
    );
    expect(result.combinationState, CapabilityState.unverified);
    expect(result.selection.liveAspects, hasLength(3));
  });

  test('unknown aspect is rejected', () {
    final enablement = OutputEnablement(releaseBuild: false);
    expect(
      () => enablement.enable(
        recording: false,
        liveAspects: const ['4:3'],
        platform: MatrixPlatform.android,
      ),
      throwsA(
        isA<OutputEnablementException>().having(
          (error) => error.reason,
          'reason',
          'aspect_unsupported',
        ),
      ),
    );
  });

  test('empty selection clears enablement', () {
    final enablement = OutputEnablement(releaseBuild: true);
    final result = enablement.enable(
      recording: false,
      liveAspects: const [],
      platform: MatrixPlatform.macos,
    );
    expect(result.selection.isEmpty, isTrue);
    expect(result.combinationState, CapabilityState.verified);
  });

  test('combination key is order-independent', () {
    expect(
      CapabilityMatrix.outputCombinationKey(
        recording: true,
        liveAspects: const ['9:16', '16:9', '1:1'],
      ),
      'recording+16:9+1:1+9:16',
    );
    expect(
      CapabilityMatrix.outputCombinationKey(
        recording: false,
        liveAspects: const [],
      ),
      'none',
    );
  });
}

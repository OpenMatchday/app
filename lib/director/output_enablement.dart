import 'package:flutter/foundation.dart' show kReleaseMode;

import '../capability_matrix.dart';

/// Live output aspects allowed by PROJECT_SPEC AC-3.1.
const List<String> outputAspects = <String>['16:9', '9:16', '1:1'];

class OutputEnablementException implements Exception {
  OutputEnablementException(this.reason, this.message);

  final String reason;
  final String message;

  @override
  String toString() => message;
}

class OutputCombinationSelection {
  const OutputCombinationSelection({
    required this.recording,
    required this.liveAspects,
  });

  final bool recording;
  final Set<String> liveAspects;

  bool get isEmpty => !recording && liveAspects.isEmpty;

  bool get streaming => liveAspects.isNotEmpty;

  OutputCombinationSelection copyWith({
    bool? recording,
    Set<String>? liveAspects,
  }) {
    return OutputCombinationSelection(
      recording: recording ?? this.recording,
      liveAspects: liveAspects ?? this.liveAspects,
    );
  }
}

class OutputEnablementResult {
  const OutputEnablementResult({
    required this.selection,
    required this.platform,
    required this.combinationState,
    this.combinationLimits,
    required this.releaseGated,
  });

  final OutputCombinationSelection selection;
  final MatrixPlatform platform;
  final CapabilityState combinationState;
  final String? combinationLimits;
  final bool releaseGated;
}

/// AC-3.1 / AC-3.11 / G7: enable recording + live aspects only when measured.
class OutputEnablement {
  OutputEnablement({
    this.matrix = const CapabilityMatrix(),
    bool? releaseBuild,
  }) : releaseBuild = releaseBuild ?? kReleaseMode;

  final CapabilityMatrix matrix;
  final bool releaseBuild;

  bool aspectSupported(String aspect, MatrixPlatform platform) {
    if (!outputAspects.contains(aspect)) {
      return false;
    }
    final note = matrix.aspectSupport(aspect, platform);
    if (!releaseBuild) {
      return true;
    }
    return note.state == CapabilityState.verified ||
        note.state == CapabilityState.partial;
  }

  /// Apply a combination. Empty selection always clears enablement.
  OutputEnablementResult enable({
    required bool recording,
    required Iterable<String> liveAspects,
    required MatrixPlatform platform,
  }) {
    final aspects = <String>{};
    for (final aspect in liveAspects) {
      if (!outputAspects.contains(aspect)) {
        throw OutputEnablementException(
          'aspect_unsupported',
          'Live output aspect $aspect is not among ${outputAspects.join(', ')}',
        );
      }
      aspects.add(aspect);
    }
    final selection = OutputCombinationSelection(
      recording: recording,
      liveAspects: aspects,
    );
    if (selection.isEmpty) {
      return OutputEnablementResult(
        selection: selection,
        platform: platform,
        combinationState: CapabilityState.verified,
        releaseGated: releaseBuild,
      );
    }
    if (!matrix.allowsOutputCombination(
      recording: recording,
      liveAspects: aspects,
      platform: platform,
      releaseBuild: releaseBuild,
    )) {
      final note = matrix.outputCombination(
        recording: recording,
        liveAspects: aspects,
        platform: platform,
      );
      throw OutputEnablementException(
        'combination_gated',
        'Output combination '
        '${CapabilityMatrix.outputCombinationKey(recording: recording, liveAspects: aspects)} '
        'is ${note.state.name} on ${platform.name} and cannot be enabled '
        'in release builds until director-class sustain is measured (AC-3.11 / G7)'
        '${note.limits == null ? '' : '; limits: ${note.limits}'}',
      );
    }
    final note = matrix.outputCombination(
      recording: recording,
      liveAspects: aspects,
      platform: platform,
    );
    return OutputEnablementResult(
      selection: selection,
      platform: platform,
      combinationState: note.state,
      combinationLimits: note.limits,
      releaseGated: releaseBuild,
    );
  }
}

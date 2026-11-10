import 'audio.dart';
import 'av_sync.dart';
import 'cut_take.dart';
import 'source_health.dart';

/// Director Preview and Program buses (AC-2.1).
///
/// Only Program may feed enabled outputs. Cut/Take is explicit (AC-2.2).
/// Camera tally follows Program (AC-2.3).
enum DirectorBus {
  preview,
  program,
}

enum PreviewSourceState {
  idle,
  starting,
  receiving,
  stopped,
  refused,
  error,
}

class PreviewSourceStatus {
  const PreviewSourceStatus({
    required this.state,
    required this.medium,
    this.platform = '',
    this.sourceId = '',
    this.message = '',
    this.snapshotPath = '',
  });

  final PreviewSourceState state;
  final String medium;
  final String platform;
  final String sourceId;
  final String message;
  final String snapshotPath;

  bool get isReceiving => state == PreviewSourceState.receiving;

  PreviewSourceStatus copyWith({
    PreviewSourceState? state,
    String? medium,
    String? platform,
    String? sourceId,
    String? message,
    String? snapshotPath,
  }) {
    return PreviewSourceStatus(
      state: state ?? this.state,
      medium: medium ?? this.medium,
      platform: platform ?? this.platform,
      sourceId: sourceId ?? this.sourceId,
      message: message ?? this.message,
      snapshotPath: snapshotPath ?? this.snapshotPath,
    );
  }
}

class DirectorBuses {
  DirectorBuses({
    PreviewSourceStatus? preview,
    this.programSourceId = '',
    this.cameraSourceIds = const ['cam-1', 'cam-2'],
    DirectorAudio? audio,
    AvSyncMonitor? avSync,
    SourceHealthBoard? health,
    this.lastCutTake,
  })  : preview = preview ??
            const PreviewSourceStatus(
              state: PreviewSourceState.idle,
              medium: '',
            ),
        audio = audio ?? DirectorAudio(),
        avSync = avSync ?? AvSyncMonitor(),
        health = health ?? SourceHealthBoard();

  PreviewSourceStatus preview;

  /// Empty until explicit Cut/Take. Program never auto-follows Preview.
  String programSourceId;

  /// Two camera sources on the director rig (OM-014).
  List<String> cameraSourceIds;

  /// Independent of Preview/Program video source (AC-2.4).
  DirectorAudio audio;

  /// A/V sync monitor (AC-2.6 / G5). Numbers from media measurements only.
  AvSyncMonitor avSync;

  /// Per-source connection health and Program fallback (AC-2.7 / AC-2.8).
  SourceHealthBoard health;

  /// Last explicit Cut/Take result (G3 timing).
  CutTakeResult? lastCutTake;

  bool get programFeedsOutputs => programSourceId.isNotEmpty;

  /// Preview source selected for Cut/Take (receiving status preferred).
  String get previewSourceForCut {
    if (preview.sourceId.isNotEmpty) {
      return preview.sourceId;
    }
    return '';
  }

  /// Explicit Cut or Take: Program becomes the current Preview source (AC-2.2).
  CutTakeResult cutTake({
    required String action,
    required String previewSourceId,
    int? issuedAtMs,
  }) {
    if (!CutTakeAction.isValid(action)) {
      throw CutTakeException('Cut/Take action must be cut or take');
    }
    if (previewSourceId.isEmpty) {
      throw CutTakeException('Cut/Take requires a Preview source');
    }
    final issued = issuedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final previous = programSourceId;
    programSourceId = previewSourceId;
    final applied = DateTime.now().millisecondsSinceEpoch;
    final result = CutTakeResult(
      action: action,
      previewSourceId: previewSourceId,
      previousProgramSourceId: previous,
      programSourceId: programSourceId,
      issuedAtMs: issued,
      appliedAtMs: applied,
    );
    lastCutTake = result;
    return result;
  }
}

import 'audio.dart';

/// Director Preview and Program buses (AC-2.1).
///
/// Only Program may feed enabled outputs. OM-013 wires the Preview path;
/// Cut/Take onto Program arrives in OM-015. OM-014 adds a second camera
/// source and an independent audio path (AC-2.4 / AC-2.5).
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
  })  : preview = preview ??
            const PreviewSourceStatus(
              state: PreviewSourceState.idle,
              medium: '',
            ),
        audio = audio ?? DirectorAudio();

  PreviewSourceStatus preview;

  /// Empty until OM-015 Cut/Take. Program never auto-follows Preview.
  String programSourceId;

  /// Two camera sources on the director rig (OM-014).
  List<String> cameraSourceIds;

  /// Independent of Preview/Program video source (AC-2.4).
  DirectorAudio audio;

  bool get programFeedsOutputs => programSourceId.isNotEmpty;
}

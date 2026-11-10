/// Director Preview and Program buses (AC-2.1).
///
/// Only Program may feed enabled outputs. OM-013 wires the Preview path;
/// Cut/Take onto Program arrives in OM-015.
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
  }) : preview = preview ??
            const PreviewSourceStatus(
              state: PreviewSourceState.idle,
              medium: '',
            );

  PreviewSourceStatus preview;

  /// Empty until OM-015 Cut/Take. Program never auto-follows Preview.
  String programSourceId;

  bool get programFeedsOutputs => programSourceId.isNotEmpty;
}

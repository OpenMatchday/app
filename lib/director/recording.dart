// Program recording session control (OM-032 / G6 / AC-3.1 recording path).
// Media plane owns the file bytes; this store tracks start/stop and refuses
// auto-restart after crash recovery (AC-5.6 with OM-019).

class RecordingSession {
  const RecordingSession({
    this.active = false,
    this.path = '',
    this.startedAtMs,
    this.stoppedAtMs,
    this.message = '',
  });

  final bool active;
  final String path;
  final int? startedAtMs;
  final int? stoppedAtMs;
  final String message;

  bool get hasFile => path.isNotEmpty;

  RecordingSession copyWith({
    bool? active,
    String? path,
    int? startedAtMs,
    int? stoppedAtMs,
    String? message,
    bool clearStartedAt = false,
    bool clearStoppedAt = false,
  }) {
    return RecordingSession(
      active: active ?? this.active,
      path: path ?? this.path,
      startedAtMs: clearStartedAt ? null : (startedAtMs ?? this.startedAtMs),
      stoppedAtMs: clearStoppedAt ? null : (stoppedAtMs ?? this.stoppedAtMs),
      message: message ?? this.message,
    );
  }
}

/// Applies recording intent changes and crash recovery without auto-restart.
class RecordingController {
  RecordingController({RecordingSession? initial})
      : session = initial ?? const RecordingSession();

  RecordingSession session;

  /// Start recording when enablement turns recording on.
  RecordingSession start({
    required String path,
    required int atMs,
  }) {
    if (path.isEmpty) {
      throw ArgumentError('recording path required');
    }
    session = RecordingSession(
      active: true,
      path: path,
      startedAtMs: atMs,
      stoppedAtMs: null,
      message: 'recording started',
    );
    return session;
  }

  /// Stop recording; keep last path for playback / export.
  RecordingSession stop({required int atMs, String message = 'recording stopped'}) {
    session = session.copyWith(
      active: false,
      stoppedAtMs: atMs,
      message: message,
    );
    return session;
  }

  /// Apply output intent. Starting requires a path from the media plane.
  RecordingSession applyIntent({
    required bool recording,
    required int atMs,
    String path = '',
  }) {
    if (recording) {
      final nextPath = path.isNotEmpty ? path : session.path;
      if (nextPath.isEmpty) {
        throw StateError('cannot start recording without a file path');
      }
      if (session.active && session.path == nextPath) {
        return session;
      }
      return start(path: nextPath, atMs: atMs);
    }
    if (!session.active) {
      return session;
    }
    return stop(atMs: atMs);
  }

  /// AC-5.6: after crash, leave recording stopped; never auto-restart.
  RecordingSession recoverStopped({required int atMs}) {
    session = RecordingSession(
      active: false,
      path: session.path,
      startedAtMs: session.startedAtMs,
      stoppedAtMs: atMs,
      message: 'outputs left stopped after crash recovery',
    );
    return session;
  }
}

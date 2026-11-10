// Connection health and Program source-loss fallback (AC-2.7 / AC-2.8).
// States match protocol common.json HealthState and session SourceHealth.

enum SourceHealthState {
  connected,
  degraded,
  lost,
}

enum ProgramFallbackMode {
  lastFrameFreeze,
  slate,
  alternateSource,
}

extension ProgramFallbackModeWire on ProgramFallbackMode {
  String get wire {
    switch (this) {
      case ProgramFallbackMode.lastFrameFreeze:
        return 'last_frame_freeze';
      case ProgramFallbackMode.slate:
        return 'slate';
      case ProgramFallbackMode.alternateSource:
        return 'alternate_source';
    }
  }

  static ProgramFallbackMode parse(String value) {
    switch (value) {
      case 'last_frame_freeze':
        return ProgramFallbackMode.lastFrameFreeze;
      case 'slate':
        return ProgramFallbackMode.slate;
      case 'alternate_source':
        return ProgramFallbackMode.alternateSource;
      default:
        throw ArgumentError('unknown program fallback: $value');
    }
  }
}

class SourceHealthEntry {
  const SourceHealthEntry({
    required this.sourceId,
    required this.state,
    required this.observedAtMs,
    this.detail = '',
  });

  final String sourceId;
  final SourceHealthState state;
  final int observedAtMs;
  final String detail;

  SourceHealthEntry copyWith({
    String? sourceId,
    SourceHealthState? state,
    int? observedAtMs,
    String? detail,
  }) {
    return SourceHealthEntry(
      sourceId: sourceId ?? this.sourceId,
      state: state ?? this.state,
      observedAtMs: observedAtMs ?? this.observedAtMs,
      detail: detail ?? this.detail,
    );
  }
}

class SourceLossFallbackResult {
  const SourceLossFallbackResult({
    required this.lostSourceId,
    required this.fallbackMode,
    required this.programSafeState,
    required this.sessionAlive,
    required this.observedAtMs,
    this.programSourceId = '',
    this.alternateSourceId = '',
    this.message = '',
  });

  final String lostSourceId;
  final ProgramFallbackMode fallbackMode;
  final String programSafeState;
  final bool sessionAlive;
  final int observedAtMs;
  final String programSourceId;
  final String alternateSourceId;
  final String message;
}

/// Director-side health board. Session stays alive across source loss (AC-2.7).
class SourceHealthBoard {
  SourceHealthBoard({
    List<SourceHealthEntry>? sources,
    this.fallbackMode = ProgramFallbackMode.lastFrameFreeze,
    this.alternateSourceId = 'cam-2',
    this.sessionAlive = true,
    this.lastFallback,
    this.message = '',
  }) : sources = sources ?? <SourceHealthEntry>[];

  List<SourceHealthEntry> sources;
  ProgramFallbackMode fallbackMode;
  String alternateSourceId;
  bool sessionAlive;
  SourceLossFallbackResult? lastFallback;
  String message;

  SourceHealthEntry? entryFor(String sourceId) {
    for (final entry in sources) {
      if (entry.sourceId == sourceId) {
        return entry;
      }
    }
    return null;
  }

  void replaceSources(List<SourceHealthEntry> next) {
    sources = List<SourceHealthEntry>.from(next);
  }

  void upsert(SourceHealthEntry entry) {
    final next = <SourceHealthEntry>[];
    var replaced = false;
    for (final existing in sources) {
      if (existing.sourceId == entry.sourceId) {
        next.add(entry);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) {
      next.add(entry);
    }
    sources = next;
  }

  /// Apply configured safe Program state when a source is lost (AC-2.7).
  /// Never tears down the director session.
  SourceLossFallbackResult applySourceLoss({
    required String lostSourceId,
    required String programSourceId,
    int? observedAtMs,
    String? alternateSourceId,
  }) {
    if (!sessionAlive) {
      throw StateError('session already dead; cannot apply source-loss fallback');
    }
    final observed = observedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    upsert(
      SourceHealthEntry(
        sourceId: lostSourceId,
        state: SourceHealthState.lost,
        observedAtMs: observed,
        detail: 'source lost',
      ),
    );

    final alt = (alternateSourceId ?? this.alternateSourceId).trim();
    late final String safeState;
    late final String nextProgram;
    late final String note;
    switch (fallbackMode) {
      case ProgramFallbackMode.lastFrameFreeze:
        safeState = 'last_frame_freeze';
        nextProgram = programSourceId.isEmpty ? lostSourceId : programSourceId;
        note = 'Program held on last frame freeze';
      case ProgramFallbackMode.slate:
        safeState = 'slate';
        nextProgram = programSourceId.isEmpty ? lostSourceId : programSourceId;
        note = 'Program switched to slate';
      case ProgramFallbackMode.alternateSource:
        if (alt.isEmpty || alt == lostSourceId) {
          throw ArgumentError(
            'alternate_source fallback requires a different alternateSourceId',
          );
        }
        safeState = 'alternate_source';
        nextProgram = alt;
        note = 'Program switched to alternate source $alt';
    }

    final result = SourceLossFallbackResult(
      lostSourceId: lostSourceId,
      fallbackMode: fallbackMode,
      programSafeState: safeState,
      sessionAlive: true,
      observedAtMs: observed,
      programSourceId: nextProgram,
      alternateSourceId: alt,
      message: note,
    );
    lastFallback = result;
    message = note;
    sessionAlive = true;
    return result;
  }
}

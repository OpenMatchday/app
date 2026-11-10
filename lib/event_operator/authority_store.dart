import 'crash_preservation.dart';
import 'event_log.dart';
import 'fields.dart';
import 'manual_timer.dart';
import 'ocr_reading.dart';

class CommandResult {
  const CommandResult({
    required this.applied,
    required this.duplicate,
    required this.message,
    this.event,
  });

  final bool applied;
  final bool duplicate;
  final String message;
  final EventRecord? event;
}

class LateJoinerSnapshot {
  const LateJoinerSnapshot({
    required this.snapshotId,
    required this.sessionId,
    required this.createdAt,
    required this.eventLogSeq,
    required this.fields,
  });

  final String snapshotId;
  final String sessionId;
  final DateTime createdAt;
  final int eventLogSeq;
  final List<FieldState> fields;

  Map<String, Object> toWire() => <String, Object>{
        'snapshot_id': snapshotId,
        'session_id': sessionId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'event_log_seq': eventLogSeq,
        'fields': fields.map((field) => field.toWire()).toList(),
      };
}

/// Authority plane: manual timer default, per-field authority, OCR gate,
/// append-only log, idempotent commands, late-joiner snapshots (AC-5.*).
class AuthorityStore {
  AuthorityStore({
    this.sessionId = 'sess-local',
    this.deviceId = 'evt-op-local',
    /// shortcut: provisional until OM-031 calibrates OCR confidence
    this.minConfidence = 0.7,
    DateTime Function()? now,
    ManualMonotonicTimer? timer,
    EventLog? eventLog,
  })  : now = now ?? DateTime.now,
        timer = timer ??
            ManualMonotonicTimer(now: now ?? DateTime.now),
        log = eventLog ?? EventLog(now: now ?? DateTime.now) {
    final clockValue = this.timer.formatMmSs();
    for (final field in ScoreField.values) {
      _fields[field] = FieldState(
        field: field,
        value: field == ScoreField.clock ? clockValue : 0,
        // AC-5.1: manual monotonic timer is the default clock authority.
        authority: FieldAuthority.manual,
      );
    }
  }

  final String sessionId;
  final String deviceId;
  final double minConfidence;
  final DateTime Function() now;
  final ManualMonotonicTimer timer;
  final EventLog log;

  final Map<ScoreField, FieldState> _fields = <ScoreField, FieldState>{};
  final Map<String, CommandResult> _commandResults = <String, CommandResult>{};
  final Map<String, LineupSideAuthority> _lineup =
      <String, LineupSideAuthority>{
    'home': const LineupSideAuthority(
      side: 'home',
      authority: FieldAuthority.manual,
    ),
    'away': const LineupSideAuthority(
      side: 'away',
      authority: FieldAuthority.manual,
    ),
  };
  OutputIntents _outputs = const OutputIntents();
  int _snapshotCounter = 0;

  /// Product copy required by AC-5.7.
  static const String broadcastAidCopy =
      'Broadcast aid only. Not official timing or scoring authority.';

  FieldState fieldState(ScoreField field) => _fields[field]!;

  List<FieldState> get allFields =>
      ScoreField.values.map(fieldState).toList(growable: false);

  List<LineupSideAuthority> get lineupAuthority =>
      <LineupSideAuthority>[_lineup['home']!, _lineup['away']!];

  OutputIntents get outputs => _outputs;

  void setOutputIntents(OutputIntents intents) {
    _outputs = intents;
  }

  CommandResult setLineupAuthority({
    required String commandId,
    required String side,
    required FieldAuthority authority,
    bool? confirmed,
    bool? locked,
    String? revision,
  }) {
    final prior = _duplicateOrNull(commandId);
    if (prior != null) {
      return prior;
    }
    final current = _lineup[side];
    if (current == null) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: 'unknown lineup side: $side',
        ),
      );
    }
    if (current.locked) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: 'lineup $side is locked',
        ),
      );
    }
    _lineup[side] = current.copyWith(
      authority: authority,
      confirmed: confirmed,
      locked: locked,
      revision: revision,
    );
    final event = log.append(
      type: 'lineup_authority_updated',
      causedByCommandId: commandId,
      payload: _lineup[side]!.toWire(),
    );
    return _remember(
      commandId,
      CommandResult(
        applied: true,
        duplicate: false,
        message: 'lineup $side updated',
        event: event,
      ),
    );
  }

  CrashCheckpoint exportCheckpoint({OutputIntents? outputs}) {
    syncClockFromTimer();
    final intents = outputs ?? _outputs;
    _outputs = intents;
    return CrashCheckpoint(
      sessionId: sessionId,
      savedAt: now(),
      fields: allFields,
      lineupAuthority: lineupAuthority,
      eventLogSeq: log.seq,
      clockElapsedMs: timer.elapsed.inMilliseconds,
      clockRunning: timer.isRunning,
      outputs: intents,
    );
  }

  /// Restore clocks/scores/lineup authority from a crash checkpoint.
  /// Does not apply output intents — caller must keep recording/streaming stopped.
  void restoreFromCheckpoint(CrashCheckpoint checkpoint) {
    for (final field in checkpoint.fields) {
      _fields[field.field] = field;
    }
    for (final side in checkpoint.lineupAuthority) {
      _lineup[side.side] = side;
    }
    timer.pause();
    timer.setElapsed(Duration(milliseconds: checkpoint.clockElapsedMs));
    syncClockFromTimer();
    // AC-5.6: never resume outputs from persisted intent.
    _outputs = const OutputIntents(recording: false, streaming: false);
  }

  void syncClockFromTimer() {
    final clock = _fields[ScoreField.clock]!;
    if (clock.locked) {
      return;
    }
    _fields[ScoreField.clock] = clock.copyWith(value: timer.formatMmSs());
  }

  CommandResult setField({
    required String commandId,
    required ScoreField field,
    required Object value,
    required FieldAuthority authority,
  }) {
    final prior = _duplicateOrNull(commandId);
    if (prior != null) {
      return prior;
    }

    final current = _fields[field]!;
    if (current.locked) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: '${field.wire} is locked',
        ),
      );
    }

    if (field == ScoreField.clock && value is String) {
      final parsed = _parseMmSs(value);
      if (parsed != null) {
        timer.setElapsed(parsed);
      }
    }

    final authorityChanged = current.authority != authority;
    _fields[field] = current.copyWith(
      value: value,
      authority: authority,
      confirmed: false,
    );

    if (authorityChanged) {
      log.append(
        type: 'authority_changed',
        causedByCommandId: commandId,
        payload: <String, Object?>{
          'field': field.wire,
          'authority': authority.wire,
        },
      );
    }

    final event = log.append(
      type: 'field_updated',
      causedByCommandId: commandId,
      payload: <String, Object?>{
        'field': field.wire,
        'value': value,
        'authority': authority.wire,
      },
    );

    return _remember(
      commandId,
      CommandResult(
        applied: true,
        duplicate: false,
        message: 'field updated',
        event: event,
      ),
    );
  }

  CommandResult confirmField({
    required String commandId,
    required ScoreField field,
    required ConfirmAction action,
    Object? correctedValue,
  }) {
    final prior = _duplicateOrNull(commandId);
    if (prior != null) {
      return prior;
    }

    final current = _fields[field]!;
    if (current.locked && action != ConfirmAction.lock) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: '${field.wire} is locked',
        ),
      );
    }

    switch (action) {
      case ConfirmAction.confirm:
        _fields[field] = current.copyWith(confirmed: true);
      case ConfirmAction.correct:
        if (correctedValue == null) {
          return _remember(
            commandId,
            CommandResult(
              applied: false,
              duplicate: false,
              message: 'corrected_value required',
            ),
          );
        }
        if (field == ScoreField.clock && correctedValue is String) {
          final parsed = _parseMmSs(correctedValue);
          if (parsed != null) {
            timer.setElapsed(parsed);
          }
        }
        _fields[field] = current.copyWith(
          value: correctedValue,
          confirmed: true,
        );
      case ConfirmAction.lock:
        _fields[field] = current.copyWith(confirmed: true, locked: true);
    }

    final event = log.append(
      type: 'field_updated',
      causedByCommandId: commandId,
      revisionOf: null,
      payload: <String, Object?>{
        'field': field.wire,
        'value': _fields[field]!.value,
        'authority': _fields[field]!.authority.wire,
        'action': action.wire,
        'confirmed': _fields[field]!.confirmed,
        'locked': _fields[field]!.locked,
      },
    );

    return _remember(
      commandId,
      CommandResult(
        applied: true,
        duplicate: false,
        message: 'field ${action.wire}',
        event: event,
      ),
    );
  }

  CommandResult applyOcrReading({
    required String commandId,
    required OcrReading reading,
  }) {
    final prior = _duplicateOrNull(commandId);
    if (prior != null) {
      return prior;
    }

    final ocrEvent = log.append(
      type: 'ocr_reading',
      causedByCommandId: commandId,
      payload: reading.toWire(),
    );

    final current = _fields[reading.field]!;
    final lowConfidence = reading.confidence < minConfidence;
    final stale = reading.stale;

    // AC-5.4: low-confidence never overrides confirmed state.
    if (current.confirmed && lowConfidence) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: 'low-confidence OCR did not override confirmed state',
          event: ocrEvent,
        ),
      );
    }

    if (current.locked || stale) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: stale ? 'stale OCR ignored' : '${reading.field.wire} locked',
          event: ocrEvent,
        ),
      );
    }

    if (current.authority != FieldAuthority.ocrAssisted) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: 'field authority is manual; OCR logged only',
          event: ocrEvent,
        ),
      );
    }

    if (lowConfidence) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: 'low-confidence OCR not applied',
          event: ocrEvent,
        ),
      );
    }

    _fields[reading.field] = current.copyWith(
      value: reading.value,
      confirmed: false,
    );

    final update = log.append(
      type: 'field_updated',
      causedByCommandId: commandId,
      payload: <String, Object?>{
        'field': reading.field.wire,
        'value': reading.value,
        'authority': FieldAuthority.ocrAssisted.wire,
        'from_ocr': true,
      },
    );

    return _remember(
      commandId,
      CommandResult(
        applied: true,
        duplicate: false,
        message: 'OCR applied',
        event: update,
      ),
    );
  }

  CommandResult undo({
    required String commandId,
    required String targetEventId,
  }) {
    final prior = _duplicateOrNull(commandId);
    if (prior != null) {
      return prior;
    }

    final target = log.recordById(targetEventId);
    if (target == null) {
      return _remember(
        commandId,
        CommandResult(
          applied: false,
          duplicate: false,
          message: 'target event not found',
        ),
      );
    }

    if (target.type == 'field_updated') {
      final fieldWire = target.payload['field']?.toString();
      if (fieldWire != null) {
        final field = ScoreFieldWire.parse(fieldWire);
        // Compensating restore: walk prior field_updated events for this field.
        Object? restoreValue = field == ScoreField.clock ? '00:00' : 0;
        FieldAuthority restoreAuthority = FieldAuthority.manual;
        bool restoreConfirmed = false;
        bool restoreLocked = false;
        for (final record in log.records) {
          if (record.eventId == targetEventId) {
            break;
          }
          if (record.type != 'field_updated') {
            continue;
          }
          if (record.payload['field']?.toString() != fieldWire) {
            continue;
          }
          restoreValue = record.payload['value'] ?? restoreValue;
          final auth = record.payload['authority']?.toString();
          if (auth != null) {
            restoreAuthority = FieldAuthorityWire.parse(auth);
          }
          restoreConfirmed = record.payload['confirmed'] == true;
          restoreLocked = record.payload['locked'] == true;
        }
        _fields[field] = FieldState(
          field: field,
          value: restoreValue ?? 0,
          authority: restoreAuthority,
          confirmed: restoreConfirmed,
          locked: restoreLocked,
        );
        if (field == ScoreField.clock && restoreValue is String) {
          final parsed = _parseMmSs(restoreValue);
          if (parsed != null) {
            timer.setElapsed(parsed);
          }
        }
      }
    }

    final event = log.append(
      type: 'compensating_undo',
      causedByCommandId: commandId,
      compensates: targetEventId,
      payload: <String, Object?>{
        'target_event_id': targetEventId,
      },
    );

    return _remember(
      commandId,
      CommandResult(
        applied: true,
        duplicate: false,
        message: 'compensating undo',
        event: event,
      ),
    );
  }

  LateJoinerSnapshot emitSnapshot({String? snapshotId}) {
    syncClockFromTimer();
    final id = snapshotId ?? 'snap-${++_snapshotCounter}';
    final snapshot = LateJoinerSnapshot(
      snapshotId: id,
      sessionId: sessionId,
      createdAt: now(),
      eventLogSeq: log.seq,
      fields: allFields,
    );
    log.append(
      type: 'snapshot_emitted',
      payload: <String, Object?>{
        'snapshot_id': id,
        'event_log_seq': snapshot.eventLogSeq,
      },
    );
    return snapshot;
  }

  /// Restore field map from a late-joiner snapshot (AC-5.5).
  void loadSnapshot(LateJoinerSnapshot snapshot) {
    for (final field in snapshot.fields) {
      _fields[field.field] = field;
      if (field.field == ScoreField.clock && field.value is String) {
        final parsed = _parseMmSs(field.value as String);
        if (parsed != null) {
          timer.pause();
          timer.setElapsed(parsed);
        }
      }
    }
  }

  CommandResult? _duplicateOrNull(String commandId) {
    final prior = _commandResults[commandId];
    if (prior == null) {
      return null;
    }
    return CommandResult(
      applied: prior.applied,
      duplicate: true,
      message: prior.message,
      event: prior.event,
    );
  }

  CommandResult _remember(String commandId, CommandResult result) {
    final stored = CommandResult(
      applied: result.applied,
      duplicate: false,
      message: result.message,
      event: result.event,
    );
    _commandResults[commandId] = stored;
    return stored;
  }

  Duration? _parseMmSs(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null || seconds < 0 || seconds > 59) {
      return null;
    }
    if (minutes < 0) {
      return null;
    }
    return Duration(minutes: minutes, seconds: seconds);
  }
}

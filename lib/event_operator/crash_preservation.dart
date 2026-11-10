import 'dart:convert';
import 'dart:io';

import 'authority_store.dart';
import 'fields.dart';

/// Output intents persisted with authority so crash recovery can refuse
/// auto-restart (AC-5.6). Recording/streaming never resume from a checkpoint.
class OutputIntents {
  const OutputIntents({
    this.recording = false,
    this.streaming = false,
  });

  final bool recording;
  final bool streaming;

  OutputIntents copyWith({bool? recording, bool? streaming}) {
    return OutputIntents(
      recording: recording ?? this.recording,
      streaming: streaming ?? this.streaming,
    );
  }

  Map<String, Object> toWire() => <String, Object>{
        'recording': recording,
        'streaming': streaming,
      };

  static OutputIntents fromWire(Map<String, Object?>? wire) {
    if (wire == null) {
      return const OutputIntents();
    }
    return OutputIntents(
      recording: wire['recording'] == true,
      streaming: wire['streaming'] == true,
    );
  }
}

/// Durable mid-event checkpoint for director/event-operator crash recovery.
class CrashCheckpoint {
  const CrashCheckpoint({
    required this.sessionId,
    required this.savedAt,
    required this.fields,
    required this.lineupAuthority,
    required this.eventLogSeq,
    required this.clockElapsedMs,
    required this.clockRunning,
    required this.outputs,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String sessionId;
  final DateTime savedAt;
  final List<FieldState> fields;
  final List<LineupSideAuthority> lineupAuthority;
  final int eventLogSeq;
  final int clockElapsedMs;
  final bool clockRunning;
  final OutputIntents outputs;

  Map<String, Object> toWire() => <String, Object>{
        'schema_version': schemaVersion,
        'session_id': sessionId,
        'saved_at': savedAt.toUtc().toIso8601String(),
        'fields': fields.map((field) => field.toWire()).toList(),
        'lineup_authority':
            lineupAuthority.map((side) => side.toWire()).toList(),
        'event_log_seq': eventLogSeq,
        'clock_elapsed_ms': clockElapsedMs,
        'clock_running': clockRunning,
        'outputs': outputs.toWire(),
      };

  static CrashCheckpoint fromWire(Map<String, Object?> wire) {
    final fieldsRaw = wire['fields'];
    final fields = <FieldState>[];
    if (fieldsRaw is List) {
      for (final item in fieldsRaw) {
        if (item is Map) {
          fields.add(
            FieldState.fromWire(Map<String, Object?>.from(item)),
          );
        }
      }
    }

    final lineupRaw = wire['lineup_authority'];
    final lineup = <LineupSideAuthority>[];
    if (lineupRaw is List) {
      for (final item in lineupRaw) {
        if (item is Map) {
          lineup.add(
            LineupSideAuthority.fromWire(Map<String, Object?>.from(item)),
          );
        }
      }
    }

    final outputsRaw = wire['outputs'];
    final outputs = outputsRaw is Map
        ? OutputIntents.fromWire(Map<String, Object?>.from(outputsRaw))
        : const OutputIntents();

    final elapsed = wire['clock_elapsed_ms'];
    final seq = wire['event_log_seq'];

    return CrashCheckpoint(
      schemaVersion: (wire['schema_version'] as num?)?.toInt() ?? 1,
      sessionId: wire['session_id']?.toString() ?? 'sess-local',
      savedAt: DateTime.tryParse(wire['saved_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      fields: fields,
      lineupAuthority: lineup,
      eventLogSeq: seq is num ? seq.toInt() : 0,
      clockElapsedMs: elapsed is num ? elapsed.toInt() : 0,
      clockRunning: wire['clock_running'] == true,
      outputs: outputs,
    );
  }
}

/// File-backed crash checkpoint IO. Inject [file] for tests.
class CrashPreservationStore {
  CrashPreservationStore({required this.file, DateTime Function()? now})
      : now = now ?? DateTime.now;

  final File file;
  final DateTime Function() now;

  bool get exists => file.existsSync();

  Future<void> save(CrashCheckpoint checkpoint) async {
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final encoded = const JsonEncoder.withIndent('  ').convert(
      checkpoint.toWire(),
    );
    await file.writeAsString(encoded);
  }

  Future<CrashCheckpoint?> load() async {
    if (!file.existsSync()) {
      return null;
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('crash checkpoint is not an object');
    }
    return CrashCheckpoint.fromWire(Map<String, Object?>.from(decoded));
  }

  /// AC-5.6: restore clocks/scores/lineup authority; never restart outputs.
  Future<CrashRecoveryResult> recoverAfterCrash(AuthorityStore store) async {
    final checkpoint = await load();
    if (checkpoint == null) {
      return CrashRecoveryResult(
        restored: false,
        outputs: const OutputIntents(),
        message: 'no checkpoint',
      );
    }

    store.restoreFromCheckpoint(checkpoint);
    // Force stopped regardless of persisted intent.
    final stopped = const OutputIntents(recording: false, streaming: false);
    return CrashRecoveryResult(
      restored: true,
      outputs: stopped,
      checkpoint: checkpoint,
      message:
          'restored authority; recording/streaming left stopped (AC-5.6)',
    );
  }
}

class CrashRecoveryResult {
  const CrashRecoveryResult({
    required this.restored,
    required this.outputs,
    required this.message,
    this.checkpoint,
  });

  final bool restored;
  final OutputIntents outputs;
  final String message;
  final CrashCheckpoint? checkpoint;

  bool get recordingRestarted => outputs.recording;
  bool get streamingRestarted => outputs.streaming;
}

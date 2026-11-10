// Append-only event log with revisions and compensating undo (AC-5.5).

class EventRecord {
  const EventRecord({
    required this.eventId,
    required this.seq,
    required this.recordedAt,
    required this.type,
    required this.payload,
    this.causedByCommandId,
    this.revisionOf,
    this.compensates,
  });

  final String eventId;
  final int seq;
  final DateTime recordedAt;
  final String type;
  final Map<String, Object?> payload;
  final String? causedByCommandId;
  final String? revisionOf;
  final String? compensates;

  Map<String, Object?> toWire() => <String, Object?>{
        'event_id': eventId,
        'seq': seq,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        if (causedByCommandId != null)
          'caused_by_command_id': causedByCommandId,
        if (revisionOf != null) 'revision_of': revisionOf,
        if (compensates != null) 'compensates': compensates,
        'type': type,
        'payload': payload,
      };
}

class EventLog {
  EventLog({this.now = DateTime.now});

  final DateTime Function() now;

  final List<EventRecord> _records = <EventRecord>[];
  int _nextSeq = 0;
  int _idCounter = 0;

  int get seq => _nextSeq;
  List<EventRecord> get records => List<EventRecord>.unmodifiable(_records);

  EventRecord? recordById(String eventId) {
    for (final record in _records) {
      if (record.eventId == eventId) {
        return record;
      }
    }
    return null;
  }

  EventRecord append({
    required String type,
    required Map<String, Object?> payload,
    String? causedByCommandId,
    String? revisionOf,
    String? compensates,
    String? eventId,
  }) {
    final id = eventId ?? 'evt-${++_idCounter}';
    final record = EventRecord(
      eventId: id,
      seq: _nextSeq,
      recordedAt: now(),
      type: type,
      payload: Map<String, Object?>.from(payload),
      causedByCommandId: causedByCommandId,
      revisionOf: revisionOf,
      compensates: compensates,
    );
    _records.add(record);
    _nextSeq += 1;
    return record;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/event_operator/authority_store.dart';
import 'package:open_matchday/event_operator/fields.dart';
import 'package:open_matchday/event_operator/manual_timer.dart';
import 'package:open_matchday/event_operator/ocr_reading.dart';

void main() {
  test('clock defaults to manual authority', () {
    final store = AuthorityStore();
    expect(store.fieldState(ScoreField.clock).authority, FieldAuthority.manual);
    expect(AuthorityStore.broadcastAidCopy, contains('Broadcast aid only'));
    expect(AuthorityStore.broadcastAidCopy, contains('Not official'));
  });

  test('manual timer is monotonic while running', () {
    var tick = DateTime.utc(2026, 11, 10, 12);
    final timer = ManualMonotonicTimer(now: () => tick);
    timer.start();
    tick = tick.add(const Duration(seconds: 5));
    expect(timer.elapsed.inSeconds, 5);
    tick = tick.add(const Duration(seconds: 3));
    expect(timer.elapsed.inSeconds, 8);
    timer.pause();
    final paused = timer.elapsed;
    tick = tick.add(const Duration(seconds: 10));
    expect(timer.elapsed, paused);
  });

  test('OCR reading carries value confidence timestamp staleness', () {
    final reading = OcrReading(
      field: ScoreField.homeScore,
      value: 12,
      confidence: 0.91,
      capturedAt: DateTime.utc(2026, 11, 10, 12),
      stale: false,
    );
    final wire = reading.toWire();
    expect(wire['value'], 12);
    expect(wire['confidence'], 0.91);
    expect(wire['captured_at'], '2026-11-10T12:00:00.000Z');
    expect(wire['stale'], isFalse);
  });

  test('authority is configurable per field with confirm correct lock', () {
    final store = AuthorityStore();
    final set = store.setField(
      commandId: 'cmd-1',
      field: ScoreField.homeScore,
      value: 10,
      authority: FieldAuthority.ocrAssisted,
    );
    expect(set.applied, isTrue);
    expect(
      store.fieldState(ScoreField.homeScore).authority,
      FieldAuthority.ocrAssisted,
    );

    final confirm = store.confirmField(
      commandId: 'cmd-2',
      field: ScoreField.homeScore,
      action: ConfirmAction.confirm,
    );
    expect(confirm.applied, isTrue);
    expect(store.fieldState(ScoreField.homeScore).confirmed, isTrue);

    final correct = store.confirmField(
      commandId: 'cmd-3',
      field: ScoreField.homeScore,
      action: ConfirmAction.correct,
      correctedValue: 11,
    );
    expect(correct.applied, isTrue);
    expect(store.fieldState(ScoreField.homeScore).value, 11);

    final lock = store.confirmField(
      commandId: 'cmd-4',
      field: ScoreField.homeScore,
      action: ConfirmAction.lock,
    );
    expect(lock.applied, isTrue);
    expect(store.fieldState(ScoreField.homeScore).locked, isTrue);
  });

  test('low-confidence OCR never overrides confirmed state', () {
    final store = AuthorityStore(minConfidence: 0.7);
    store.setField(
      commandId: 'cmd-a',
      field: ScoreField.homeScore,
      value: 5,
      authority: FieldAuthority.ocrAssisted,
    );
    store.confirmField(
      commandId: 'cmd-b',
      field: ScoreField.homeScore,
      action: ConfirmAction.confirm,
    );

    final result = store.applyOcrReading(
      commandId: 'cmd-c',
      reading: OcrReading(
        field: ScoreField.homeScore,
        value: 99,
        confidence: 0.2,
        capturedAt: DateTime.utc(2026, 11, 10, 12),
        stale: false,
      ),
    );

    expect(result.applied, isFalse);
    expect(store.fieldState(ScoreField.homeScore).value, 5);
    expect(
      store.log.records.where((r) => r.type == 'ocr_reading'),
      isNotEmpty,
    );
  });

  test('high-confidence OCR can update unconfirmed ocr_assisted field', () {
    final store = AuthorityStore(minConfidence: 0.7);
    store.setField(
      commandId: 'cmd-d',
      field: ScoreField.homeScore,
      value: 1,
      authority: FieldAuthority.ocrAssisted,
    );

    final result = store.applyOcrReading(
      commandId: 'cmd-e',
      reading: OcrReading(
        field: ScoreField.homeScore,
        value: 8,
        confidence: 0.95,
        capturedAt: DateTime.utc(2026, 11, 10, 12),
        stale: false,
      ),
    );

    expect(result.applied, isTrue);
    expect(store.fieldState(ScoreField.homeScore).value, 8);
  });

  test('event log is append-only with compensating undo and idempotent cmds', () {
    final store = AuthorityStore();
    final first = store.setField(
      commandId: 'cmd-idem',
      field: ScoreField.awayScore,
      value: 3,
      authority: FieldAuthority.manual,
    );
    final dup = store.setField(
      commandId: 'cmd-idem',
      field: ScoreField.awayScore,
      value: 99,
      authority: FieldAuthority.manual,
    );

    expect(first.applied, isTrue);
    expect(dup.duplicate, isTrue);
    expect(store.fieldState(ScoreField.awayScore).value, 3);
    expect(store.log.seq, 1);

    final second = store.setField(
      commandId: 'cmd-next',
      field: ScoreField.awayScore,
      value: 4,
      authority: FieldAuthority.manual,
    );
    expect(store.fieldState(ScoreField.awayScore).value, 4);

    final undo = store.undo(
      commandId: 'cmd-undo',
      targetEventId: second.event!.eventId,
    );
    expect(undo.applied, isTrue);
    expect(undo.event!.type, 'compensating_undo');
    expect(undo.event!.compensates, second.event!.eventId);
    expect(store.fieldState(ScoreField.awayScore).value, 3);
    expect(store.log.records.length, greaterThanOrEqualTo(3));
    expect(
      store.log.records.map((r) => r.seq).toList(),
      orderedEquals(
        List<int>.generate(store.log.records.length, (i) => i),
      ),
    );
  });

  test('late-joiner snapshot carries fields and event_log_seq', () {
    final store = AuthorityStore(sessionId: 'sess-1');
    store.setField(
      commandId: 'cmd-s1',
      field: ScoreField.homeScore,
      value: 12,
      authority: FieldAuthority.manual,
    );
    store.confirmField(
      commandId: 'cmd-s2',
      field: ScoreField.homeScore,
      action: ConfirmAction.confirm,
    );

    final seqBeforeSnapshot = store.log.seq;
    final snapshot = store.emitSnapshot(snapshotId: 'snap-1');
    expect(snapshot.snapshotId, 'snap-1');
    expect(snapshot.eventLogSeq, seqBeforeSnapshot);
    expect(store.log.seq, seqBeforeSnapshot + 1);
    expect(
      snapshot.fields.any(
        (f) =>
            f.field == ScoreField.homeScore &&
            f.value == 12 &&
            f.confirmed == true,
      ),
      isTrue,
    );
    expect(snapshot.fields.any((f) => f.field == ScoreField.clock), isTrue);
    expect(
      snapshot.fields
          .firstWhere((f) => f.field == ScoreField.clock)
          .authority,
      FieldAuthority.manual,
    );

    final joiner = AuthorityStore(sessionId: 'sess-1');
    joiner.loadSnapshot(snapshot);
    expect(joiner.fieldState(ScoreField.homeScore).value, 12);
    expect(joiner.fieldState(ScoreField.homeScore).confirmed, isTrue);
  });
}

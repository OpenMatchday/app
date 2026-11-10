import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/event_operator/authority_store.dart';
import 'package:open_matchday/event_operator/crash_preservation.dart';
import 'package:open_matchday/event_operator/fields.dart';
import 'package:open_matchday/media_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('om019-crash-');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('kill director mid-event restores clocks scores lineup authority',
      () async {
    final file = File('${tempDir.path}/checkpoint.json');
    final store = AuthorityStore(sessionId: 'sess-crash');
    store.timer.start();
    store.setField(
      commandId: 'cmd-home',
      field: ScoreField.homeScore,
      value: 21,
      authority: FieldAuthority.manual,
    );
    store.confirmField(
      commandId: 'cmd-home-confirm',
      field: ScoreField.homeScore,
      action: ConfirmAction.confirm,
    );
    store.setField(
      commandId: 'cmd-away',
      field: ScoreField.awayScore,
      value: 18,
      authority: FieldAuthority.manual,
    );
    store.setLineupAuthority(
      commandId: 'cmd-lineup-home',
      side: 'home',
      authority: FieldAuthority.manual,
      confirmed: true,
      revision: 'rev-home-1',
    );
    store.setOutputIntents(
      const OutputIntents(recording: true, streaming: true),
    );

    final persistence = CrashPreservationStore(file: file);
    await persistence.save(store.exportCheckpoint());

    // Simulate director process kill: new store, same durable file.
    final revived = AuthorityStore(sessionId: 'sess-crash');
    final recovery = await persistence.recoverAfterCrash(revived);

    expect(recovery.restored, isTrue);
    expect(recovery.recordingRestarted, isFalse);
    expect(recovery.streamingRestarted, isFalse);
    expect(revived.fieldState(ScoreField.homeScore).value, 21);
    expect(revived.fieldState(ScoreField.homeScore).confirmed, isTrue);
    expect(revived.fieldState(ScoreField.awayScore).value, 18);
    expect(revived.lineupAuthority.first.side, 'home');
    expect(revived.lineupAuthority.first.confirmed, isTrue);
    expect(revived.lineupAuthority.first.revision, 'rev-home-1');
    expect(revived.outputs.recording, isFalse);
    expect(revived.outputs.streaming, isFalse);
    expect(revived.timer.isRunning, isFalse);
  });

  test('persisted recording streaming intents never auto-restart', () async {
    final file = File('${tempDir.path}/outputs.json');
    final store = AuthorityStore();
    store.setOutputIntents(
      const OutputIntents(recording: true, streaming: true),
    );
    final persistence = CrashPreservationStore(file: file);
    final checkpoint = store.exportCheckpoint();
    expect(checkpoint.outputs.recording, isTrue);
    expect(checkpoint.outputs.streaming, isTrue);
    await persistence.save(checkpoint);

    final revived = AuthorityStore();
    final recovery = await persistence.recoverAfterCrash(revived);
    expect(recovery.outputs.recording, isFalse);
    expect(recovery.outputs.streaming, isFalse);
    expect(revived.outputs.recording, isFalse);
    expect(revived.outputs.streaming, isFalse);
  });

  test('MediaBridge recoverOutputsStopped forces stopped intents', () async {
    var recording = true;
    var streaming = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      (call) async {
        if (call.method == 'setOutputIntents') {
          final args = Map<String, Object?>.from(call.arguments as Map);
          recording = args['recording'] == true;
          streaming = args['streaming'] == true;
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': recording,
            'streaming': streaming,
          };
        }
        if (call.method == 'readOutputIntents') {
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': recording,
            'streaming': streaming,
          };
        }
        if (call.method == 'recoverOutputsStopped') {
          recording = false;
          streaming = false;
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': false,
            'streaming': false,
            'message': 'outputs left stopped after crash recovery',
          };
        }
        return null;
      },
    );

    final bridge = MediaBridge();
    await bridge.setOutputIntents(recording: true, streaming: true);
    final before = await bridge.readOutputIntents();
    expect(before.recording, isTrue);
    expect(before.streaming, isTrue);

    final after = await bridge.recoverOutputsStopped();
    expect(after.recording, isFalse);
    expect(after.streaming, isFalse);
    final read = await bridge.readOutputIntents();
    expect(read.recording, isFalse);
    expect(read.streaming, isFalse);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      null,
    );
  });
}

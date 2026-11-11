import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/recording.dart';
import 'package:open_matchday/media_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start then stop keeps path for playback', () {
    final controller = RecordingController();
    final started = controller.start(path: 'program_test.mp4', atMs: 1000);
    expect(started.active, isTrue);
    expect(started.path, 'program_test.mp4');
    expect(started.startedAtMs, 1000);

    final stopped = controller.stop(atMs: 2500);
    expect(stopped.active, isFalse);
    expect(stopped.path, 'program_test.mp4');
    expect(stopped.stoppedAtMs, 2500);
    expect(stopped.hasFile, isTrue);
  });

  test('applyIntent start requires path', () {
    final controller = RecordingController();
    expect(
      () => controller.applyIntent(recording: true, atMs: 1),
      throwsA(isA<StateError>()),
    );
  });

  test('crash recover leaves recording stopped without auto-restart', () {
    final controller = RecordingController();
    controller.start(path: 'mid_event.mp4', atMs: 10);
    expect(controller.session.active, isTrue);

    final recovered = controller.recoverStopped(atMs: 99);
    expect(recovered.active, isFalse);
    expect(recovered.path, 'mid_event.mp4');
    expect(recovered.message, contains('stopped after crash recovery'));

    // Intent from a checkpoint must not restart without explicit apply.
    expect(controller.session.active, isFalse);
  });

  test('MediaBridge setOutputIntents exposes recording path and active', () async {
    var recording = false;
    var streaming = false;
    var recordingActive = false;
    var recordingPath = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      (call) async {
        if (call.method == 'setOutputIntents') {
          final args = Map<String, Object?>.from(call.arguments as Map);
          recording = args['recording'] == true;
          streaming = args['streaming'] == true;
          if (recording) {
            if (!recordingActive) {
              recordingPath = 'recording_stub.mp4';
              recordingActive = true;
            }
          } else {
            recordingActive = false;
          }
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': recording,
            'streaming': streaming,
            'recordingPath': recordingPath,
            'recordingActive': recordingActive,
          };
        }
        if (call.method == 'recoverOutputsStopped') {
          recording = false;
          streaming = false;
          recordingActive = false;
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': false,
            'streaming': false,
            'recordingPath': recordingPath,
            'recordingActive': false,
            'message': 'outputs left stopped after crash recovery',
          };
        }
        return null;
      },
    );

    final bridge = MediaBridge();
    final started = await bridge.setOutputIntents(
      recording: true,
      streaming: false,
    );
    expect(started.recording, isTrue);
    expect(started.recordingActive, isTrue);
    expect(started.recordingPath, 'recording_stub.mp4');

    final controller = RecordingController();
    controller.applyIntent(
      recording: true,
      atMs: 1,
      path: started.recordingPath,
    );
    expect(controller.session.active, isTrue);

    final recovered = await bridge.recoverOutputsStopped();
    expect(recovered.recording, isFalse);
    expect(recovered.recordingActive, isFalse);
    controller.recoverStopped(atMs: 2);
    expect(controller.session.active, isFalse);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      null,
    );
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/live_outputs.dart';
import 'package:open_matchday/media_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('plan assigns independent layout ids per aspect', () {
    final controller = LiveOutputsController();
    final planned = controller.plan(
      liveAspects: const ['16:9', '9:16', '1:1'],
    );
    expect(planned, hasLength(3));
    expect(
      planned.map((d) => d.layoutId).toSet(),
      {'live-16x9', 'live-9x16', 'live-1x1'},
    );
    expect(planned.every((d) => d.kind == 'file'), isTrue);
  });

  test('silent fork of layout ids is refused', () {
    final controller = LiveOutputsController();
    expect(
      () => controller.plan(
        liveAspects: const ['16:9', '9:16'],
        layoutIds: const {'16:9': 'shared', '9:16': 'shared'},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('applyIntent start/stop and crash leave streaming stopped', () {
    final controller = LiveOutputsController();
    controller.applyIntent(liveAspects: const ['16:9', '1:1']);
    expect(controller.streaming, isTrue);
    expect(controller.activeAspects, {'16:9', '1:1'});

    controller.stop();
    expect(controller.streaming, isFalse);
    expect(controller.destinations, hasLength(2));

    controller.applyIntent(liveAspects: const ['9:16']);
    expect(controller.streaming, isTrue);
    final recovered = controller.recoverStopped();
    expect(recovered.every((d) => !d.active), isTrue);
    expect(controller.streaming, isFalse);
  });

  test('MediaBridge setOutputIntents carries liveOutputs payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      (call) async {
        if (call.method == 'setOutputIntents') {
          final args = Map<String, Object?>.from(call.arguments as Map);
          final streaming = args['streaming'] == true;
          final live = (args['liveOutputs'] as List?)
                  ?.map((entry) {
                    final row = Map<String, Object?>.from(entry as Map);
                    return <String, Object?>{
                      ...row,
                      'active': streaming,
                    };
                  })
                  .toList() ??
              <Map<String, Object?>>[];
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': args['recording'] == true,
            'streaming': streaming,
            'recordingPath': '',
            'recordingActive': false,
            'streamingActive': streaming && live.isNotEmpty,
            'liveOutputs': live,
          };
        }
        if (call.method == 'recoverOutputsStopped') {
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': false,
            'streaming': false,
            'recordingPath': '',
            'recordingActive': false,
            'streamingActive': false,
            'liveOutputs': <Map<String, Object?>>[
              <String, Object?>{
                'aspect': '16:9',
                'layoutId': 'live-16x9',
                'kind': 'file',
                'url': 'file:live_16x9.ts',
                'active': false,
              },
            ],
            'message': 'outputs left stopped after crash recovery',
          };
        }
        return null;
      },
    );

    final bridge = MediaBridge();
    final planned = LiveOutputsController().plan(
      liveAspects: const ['16:9', '9:16'],
    );
    final started = await bridge.setOutputIntents(
      recording: false,
      streaming: true,
      liveAspects: const ['16:9', '9:16'],
      liveOutputs: planned.map((d) => d.toWire()).toList(),
    );
    expect(started.streaming, isTrue);
    expect(started.streamingActive, isTrue);
    expect(started.liveOutputs, hasLength(2));
    expect(started.liveOutputs.map((d) => d.layoutId).toSet(), {
      'live-16x9',
      'live-9x16',
    });

    final recovered = await bridge.recoverOutputsStopped();
    expect(recovered.streaming, isFalse);
    expect(recovered.streamingActive, isFalse);
    expect(recovered.liveOutputs.every((d) => !d.active), isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      null,
    );
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/media_bridge.dart';
import 'package:open_matchday/pairing/media_medium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pingMedia maps platform channel payload', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'ping');
      return <String, Object>{
        'platform': 'test',
        'stamp': '42',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.pingMedia();
    expect(result.platform, 'test');
    expect(result.stamp, '42');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startPreview refuses cellular before channel call', () async {
    const channel = MethodChannel('open_matchday/media');
    var invoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      invoked = true;
      return <String, Object>{'ok': true};
    });

    final bridge = MediaBridge(channel: channel);
    expect(
      () => bridge.startPreview(medium: 'cellular'),
      throwsA(isA<MediaMediumRefused>()),
    );
    expect(invoked, isFalse);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startPreview maps wifi payload', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'startPreview');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'medium': 'wifi',
        'sourceId': 'cam-1',
        'message': 'Preview receiving on wifi',
        'snapshotPath': 'preview/out/director_preview.jpg',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.startPreview(medium: 'wifi');
    expect(result.medium, 'wifi');
    expect(result.sourceId, 'cam-1');
    expect(result.snapshotPath, 'preview/out/director_preview.jpg');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('selectAudioSource does not follow video', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'selectAudioSource');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['followsVideo'], isFalse);
      expect(args['sourceId'], 'aud-2');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'sourceId': 'aud-2',
        'followsVideo': false,
        'label': 'aud-2',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.selectAudioSource(
      sourceId: 'aud-2',
      videoProgramSourceId: 'cam-1',
    );
    expect(result.followsVideo, isFalse);
    expect(result.sourceId, 'aud-2');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('readAudioMeters maps peak and rms', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'readAudioMeters');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'sourceId': 'aud-1',
        'peakDb': -18.0,
        'rmsDb': -24.0,
      };
    });

    final bridge = MediaBridge(channel: channel);
    final meters = await bridge.readAudioMeters(sourceId: 'aud-1');
    expect(meters.peakDb, -18.0);
    expect(meters.rmsDb, -24.0);
    expect(meters.sourceId, 'aud-1');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('cutTake maps explicit action and refuses auto flag path', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'cutTake');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['autoSwitch'], isFalse);
      expect(args['action'], 'cut');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'action': 'cut',
        'previewSourceId': 'cam-2',
        'programSourceId': 'cam-2',
        'previousProgramSourceId': 'cam-1',
        'issuedAtMs': 10,
        'appliedAtMs': 14,
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.cutTake(
      action: 'cut',
      previewSourceId: 'cam-2',
      programSourceId: 'cam-2',
      previousProgramSourceId: 'cam-1',
    );
    expect(result.cutLatencyMs, 4);
    expect(result.programSourceId, 'cam-2');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setTally maps on-air flag', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'setTally');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'sourceId': 'cam-1',
        'onAir': true,
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.setTally(sourceId: 'cam-1', onAir: true);
    expect(result.onAir, isTrue);
    expect(result.sourceId, 'cam-1');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('readAvSync maps offset and correction', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'readAvSync');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'offsetMs': 80.0,
        'measuredAtMs': 2000,
        'correctionMs': 0.0,
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.readAvSync();
    expect(result.offsetMs, 80.0);
    expect(result.measuredAtMs, 2000);
    expect(result.correctionMs, 0.0);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('applyDriftCorrection maps residual', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'applyDriftCorrection');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['correctionMs'], 80.0);
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'offsetMs': 0.0,
        'measuredAtMs': 2100,
        'correctionMs': 80.0,
        'residualMs': 0.0,
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.applyDriftCorrection(correctionMs: 80);
    expect(result.correctionMs, 80.0);
    expect(result.residualMs, 0.0);
    expect(result.offsetMs, 0.0);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('readSourceHealth maps states and timestamps', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'readSourceHealth');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'sources': <Object>[
          <String, Object>{
            'sourceId': 'cam-1',
            'state': 'connected',
            'observedAtMs': 5000,
            'detail': '',
          },
          <String, Object>{
            'sourceId': 'cam-2',
            'state': 'degraded',
            'observedAtMs': 5001,
            'detail': 'jitter',
          },
        ],
        'programFallback': 'last_frame_freeze',
        'sessionAlive': true,
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.readSourceHealth();
    expect(result.sessionAlive, isTrue);
    expect(result.sources, hasLength(2));
    expect(result.sources.first.sourceId, 'cam-1');
    expect(result.sources.first.observedAtMs, 5000);
    expect(result.sources.last.state.name, 'degraded');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('applySourceLossFallback keeps sessionAlive', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'applySourceLossFallback');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['lostSourceId'], 'cam-1');
      expect(args['programFallback'], 'slate');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'lostSourceId': 'cam-1',
        'programSafeState': 'slate',
        'programSourceId': 'cam-1',
        'sessionAlive': true,
        'observedAtMs': 6000,
        'message': 'Program switched to slate',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.applySourceLossFallback(
      lostSourceId: 'cam-1',
      programSourceId: 'cam-1',
      programFallback: 'slate',
    );
    expect(result.sessionAlive, isTrue);
    expect(result.programSafeState, 'slate');
    expect(result.observedAtMs, 6000);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('probeCameraMove returns MAD and moved flag', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'probeCameraMove');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'sourceId': 'scoreboard-1',
        'moved': true,
        'mad': 31.2344,
        'threshold': 15.6172,
        'message': 'camera_move_detected',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.probeCameraMove();
    expect(result.moved, isTrue);
    expect(result.mad, 31.2344);
    expect(result.threshold, 15.6172);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('readOcrRegion returns AC-5.2 reading shape', () async {
    const channel = MethodChannel('open_matchday/media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'readOcrRegion');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['fieldId'], 'home_score');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'fieldId': 'home_score',
        'value': 78,
        'confidence': 1.0,
        'capturedAt': '2026-11-10T20:00:00.000Z',
        'stale': false,
        'rawText': '78',
        'confidenceSignal': 'digit_parse_quality',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.readOcrRegion(fieldId: 'home_score');
    expect(result.value, 78);
    expect(result.confidence, 1.0);
    expect(result.stale, isFalse);
    expect(result.confidenceSignal, 'digit_parse_quality');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

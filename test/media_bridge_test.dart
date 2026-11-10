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
}

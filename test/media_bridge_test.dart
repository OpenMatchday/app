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
}

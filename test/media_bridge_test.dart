import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/media_bridge.dart';

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
}

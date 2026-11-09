import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/media_bridge.dart';
import 'package:open_matchday/pairing/media_medium.dart';

void main() {
  test('allowlist is wifi and ethernet only', () {
    expect(isAllowedMediaMedium('wifi'), isTrue);
    expect(isAllowedMediaMedium('ethernet'), isTrue);
    expect(isAllowedMediaMedium('cellular'), isFalse);
    expect(isAllowedMediaMedium('ble'), isFalse);
    expect(mediaMediumRefusalReason('cellular'), contains('Wi-Fi or Ethernet'));
  });

  test('MediaBridge.startMedia refuses cellular before channel call', () async {
    const channel = MethodChannel('open_matchday/media');
    var called = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      called = true;
      return <String, Object>{'ok': true, 'platform': 'test', 'medium': 'wifi'};
    });

    final bridge = MediaBridge(channel: channel);
    expect(
      () => bridge.startMedia(medium: 'cellular'),
      throwsA(isA<MediaMediumRefused>()),
    );
    expect(called, isFalse);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('MediaBridge.startMedia accepts wifi', () async {
    const channel = MethodChannel('open_matchday/media');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'startMedia');
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      expect(args['medium'], 'wifi');
      return <String, Object>{
        'ok': true,
        'platform': 'test',
        'medium': 'wifi',
      };
    });

    final bridge = MediaBridge(channel: channel);
    final result = await bridge.startMedia(medium: 'wifi');
    expect(result.medium, 'wifi');
    expect(result.platform, 'test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

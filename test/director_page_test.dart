import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/director/director_page.dart';
import 'package:open_matchday/media_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      (MethodCall call) async {
        calls.add(call);
        if (call.method == 'startPreview') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final medium = args['medium']?.toString() ?? '';
          if (medium != 'wifi' && medium != 'ethernet') {
            return <String, Object>{
              'ok': false,
              'platform': 'test',
              'medium': medium,
              'error': 'refused',
            };
          }
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'medium': medium,
            'sourceId': args['sourceId']?.toString() ?? 'cam-1',
            'message': 'Preview receiving on $medium',
            'snapshotPath': 'preview/out/director_preview.jpg',
          };
        }
        if (call.method == 'stopPreview') {
          return <String, Object>{'ok': true, 'platform': 'test'};
        }
        return <String, Object>{'ok': true};
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      null,
    );
  });

  testWidgets('director shows distinct Preview and Program buses',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(mediaBridge: MediaBridge()),
      ),
    );

    expect(find.byKey(const Key('preview-bus')), findsOneWidget);
    expect(find.byKey(const Key('program-bus')), findsOneWidget);
    expect(find.textContaining('Program: none'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-preview')));
    await tester.pumpAndSettle();

    expect(find.textContaining('State: receiving'), findsOneWidget);
    expect(find.textContaining('Source: cam-1'), findsOneWidget);
    expect(calls.map((c) => c.method), contains('startPreview'));
  });

  testWidgets('director refuses cellular before channel when selected',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(
          mediaBridge: MediaBridge(),
          initialMedium: 'cellular',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('start-preview')));
    await tester.pumpAndSettle();

    expect(find.textContaining('State: refused'), findsOneWidget);
    expect(calls.where((c) => c.method == 'startPreview'), isEmpty);
  });
}

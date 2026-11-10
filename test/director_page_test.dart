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
        if (call.method == 'selectAudioSource') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'sourceId': args['sourceId']?.toString() ?? 'aud-1',
            'followsVideo': false,
            'label': args['sourceId']?.toString() ?? 'aud-1',
          };
        }
        if (call.method == 'readAudioMeters') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'sourceId': args['sourceId']?.toString() ?? '',
            'peakDb': -12.5,
            'rmsDb': -20.0,
          };
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
    view.physicalSize = const Size(1200, 2200);
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
    expect(find.byKey(const Key('audio-panel')), findsOneWidget);
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
    view.physicalSize = const Size(1200, 2200);
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

  testWidgets('audio source selectable with visible meters', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(mediaBridge: MediaBridge()),
      ),
    );

    expect(find.byKey(const Key('audio-meter-peak')), findsOneWidget);
    expect(find.byKey(const Key('audio-meter-rms')), findsOneWidget);

    await tester.tap(find.byKey(const Key('audio-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mic / line 2').last);
    await tester.pumpAndSettle();

    expect(
      calls.map((c) => c.method),
      containsAll(<String>['selectAudioSource', 'readAudioMeters']),
    );
    expect(find.textContaining('Peak: -12.5 dB'), findsOneWidget);
    expect(find.textContaining('RMS: -20.0 dB'), findsOneWidget);
    expect(find.textContaining('Selected: aud-2'), findsOneWidget);

    final select = calls.firstWhere((c) => c.method == 'selectAudioSource');
    final args = Map<Object?, Object?>.from(select.arguments as Map);
    expect(args['followsVideo'], isFalse);
    expect(args['sourceId'], 'aud-2');
  });

  testWidgets('preview can start on cam-2 without changing audio',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(
          mediaBridge: MediaBridge(),
          initialPreviewSourceId: 'cam-2',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('audio-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mic / line 1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-preview')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Source: cam-2'), findsOneWidget);
    expect(find.textContaining('Selected: aud-1'), findsOneWidget);
    final previewCall =
        calls.firstWhere((c) => c.method == 'startPreview');
    final previewArgs =
        Map<Object?, Object?>.from(previewCall.arguments as Map);
    expect(previewArgs['sourceId'], 'cam-2');
  });
}

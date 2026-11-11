import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/capability_matrix.dart';
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
        if (call.method == 'cutTake') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          expect(args['autoSwitch'], isFalse);
          final action = args['action']?.toString() ?? '';
          final preview = args['previewSourceId']?.toString() ?? '';
          final program = args['programSourceId']?.toString() ?? '';
          if (action != 'cut' && action != 'take') {
            return <String, Object>{
              'ok': false,
              'platform': 'test',
              'error': 'bad action',
            };
          }
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'action': action,
            'previewSourceId': preview,
            'programSourceId': program,
            'previousProgramSourceId':
                args['previousProgramSourceId']?.toString() ?? '',
            'issuedAtMs': 1000,
            'appliedAtMs': 1005,
          };
        }
        if (call.method == 'setTally') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'sourceId': args['sourceId']?.toString() ?? '',
            'onAir': args['onAir'] == true,
          };
        }
        if (call.method == 'readAvSync') {
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'offsetMs': 80.0,
            'measuredAtMs': 3000,
            'correctionMs': 0.0,
          };
        }
        if (call.method == 'applyDriftCorrection') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final correction = (args['correctionMs'] as num?)?.toDouble() ?? 0.0;
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'offsetMs': 0.0,
            'measuredAtMs': 3100,
            'correctionMs': correction,
            'residualMs': 0.0,
          };
        }
        if (call.method == 'readSourceHealth') {
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'sources': <Object>[
              <String, Object>{
                'sourceId': 'cam-1',
                'state': 'connected',
                'observedAtMs': 4000,
                'detail': '',
              },
              <String, Object>{
                'sourceId': 'cam-2',
                'state': 'connected',
                'observedAtMs': 4000,
                'detail': '',
              },
            ],
            'programFallback': 'last_frame_freeze',
            'sessionAlive': true,
          };
        }
        if (call.method == 'applySourceLossFallback') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final lost = args['lostSourceId']?.toString() ?? '';
          final fallback =
              args['programFallback']?.toString() ?? 'last_frame_freeze';
          final alternate = args['alternateSourceId']?.toString() ?? 'cam-2';
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'lostSourceId': lost,
            'programSafeState': fallback,
            'programSourceId':
                fallback == 'alternate_source' ? alternate : lost,
            'sessionAlive': true,
            'observedAtMs': 4500,
            'message': 'Program held on last frame freeze',
          };
        }
        if (call.method == 'setOutputIntents') {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final recording = args['recording'] == true;
          return <String, Object>{
            'ok': true,
            'platform': 'test',
            'recording': recording,
            'streaming': args['streaming'] == true,
            'recordingPath': recording ? 'recording_test.mp4' : '',
            'recordingActive': recording,
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

  testWidgets('explicit Cut puts Preview onto Program and sets tally',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    var programCallback = '';
    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(
          mediaBridge: MediaBridge(),
          onProgramChanged: (id) => programCallback = id,
        ),
      ),
    );

    expect(find.textContaining('Program: none'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-preview')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cut-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Program: cam-1'), findsOneWidget);
    expect(find.textContaining('Last cut:'), findsOneWidget);
    expect(programCallback, 'cam-1');
    expect(calls.map((c) => c.method), containsAll(<String>['cutTake', 'setTally']));

    final cut = calls.firstWhere((c) => c.method == 'cutTake');
    final cutArgs = Map<Object?, Object?>.from(cut.arguments as Map);
    expect(cutArgs['action'], 'cut');
    expect(cutArgs['autoSwitch'], isFalse);
    expect(cutArgs['programSourceId'], 'cam-1');

    final tallyCalls = calls.where((c) => c.method == 'setTally').toList();
    expect(tallyCalls, isNotEmpty);
    final tallyArgs =
        Map<Object?, Object?>.from(tallyCalls.last.arguments as Map);
    expect(tallyArgs['sourceId'], 'cam-1');
    expect(tallyArgs['onAir'], isTrue);
  });

  testWidgets('Take switches Program from cam-1 to cam-2', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(
          mediaBridge: MediaBridge(),
          initialPreviewSourceId: 'cam-1',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('start-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cut-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Program: cam-1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cam-2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('take-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Program: cam-2'), findsOneWidget);
    expect(find.textContaining('cam-1 -> cam-2'), findsOneWidget);
    final take = calls.lastWhere((c) => c.method == 'cutTake');
    final takeArgs = Map<Object?, Object?>.from(take.arguments as Map);
    expect(takeArgs['action'], 'take');
    expect(takeArgs['programSourceId'], 'cam-2');
  });

  testWidgets('A/V sync monitor measures and applies drift correction',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(mediaBridge: MediaBridge()),
      ),
    );

    expect(find.byKey(const Key('av-sync-panel')), findsOneWidget);
    expect(find.textContaining('Offset: --'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('refresh-av-sync')));
    await tester.tap(find.byKey(const Key('refresh-av-sync')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Offset: 80.0 ms'), findsOneWidget);
    expect(calls.map((c) => c.method), contains('readAvSync'));

    await tester.ensureVisible(find.byKey(const Key('apply-drift-correction')));
    await tester.tap(find.byKey(const Key('apply-drift-correction')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Correction applied: 80.0 ms'), findsOneWidget);
    expect(find.textContaining('residual 0.0 ms'), findsOneWidget);
    expect(calls.map((c) => c.method), contains('applyDriftCorrection'));
    final corr = calls.lastWhere((c) => c.method == 'applyDriftCorrection');
    final corrArgs = Map<Object?, Object?>.from(corr.arguments as Map);
    expect(corrArgs['correctionMs'], 80.0);
  });

  testWidgets('source health refresh and cam-1 drop keep session alive',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 3200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(mediaBridge: MediaBridge()),
      ),
    );

    expect(find.byKey(const Key('source-health-panel')), findsOneWidget);
    expect(find.textContaining('Director session: alive'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('refresh-source-health')));
    await tester.tap(find.byKey(const Key('refresh-source-health')));
    await tester.pumpAndSettle();

    expect(find.textContaining('cam-1: connected'), findsOneWidget);
    expect(calls.map((c) => c.method), contains('readSourceHealth'));

    await tester.ensureVisible(
      find.byKey(const Key('simulate-source-loss-cam-1')),
    );
    await tester.tap(find.byKey(const Key('simulate-source-loss-cam-1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Director session: alive'), findsOneWidget);
    expect(find.textContaining('cam-1: lost'), findsOneWidget);
    expect(find.textContaining('Last fallback:'), findsOneWidget);
    expect(
      calls.map((c) => c.method),
      contains('applySourceLossFallback'),
    );
  });

  testWidgets('release build blocks unverified output enablement',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 3600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(
          mediaBridge: MediaBridge(),
          releaseBuild: true,
          platform: MatrixPlatform.windows,
        ),
      ),
    );

    expect(find.byKey(const Key('output-enablement-panel')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('output-recording')));
    await tester.tap(find.byKey(const Key('output-recording')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('output-aspect-16:9')));
    await tester.pumpAndSettle();

    expect(find.textContaining('blocked in release'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('apply-output-enablement')));
    await tester.tap(find.byKey(const Key('apply-output-enablement')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot be enabled in release builds'),
      findsOneWidget,
    );
    expect(calls.map((c) => c.method), isNot(contains('setOutputIntents')));
  });

  testWidgets('non-release enablement applies intents for measurement',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 3600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorPage(
          mediaBridge: MediaBridge(),
          releaseBuild: false,
          platform: MatrixPlatform.windows,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('output-recording')));
    await tester.tap(find.byKey(const Key('output-recording')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('output-aspect-16:9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('output-aspect-9:16')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('apply-output-enablement')));
    await tester.tap(find.byKey(const Key('apply-output-enablement')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enabled recording+16:9+9:16'), findsOneWidget);
    expect(
      find.textContaining('Recording: active (recording_test.mp4)'),
      findsOneWidget,
    );
    final intent = calls.lastWhere((c) => c.method == 'setOutputIntents');
    final args = Map<Object?, Object?>.from(intent.arguments as Map);
    expect(args['recording'], isTrue);
    expect(args['streaming'], isTrue);
  });
}

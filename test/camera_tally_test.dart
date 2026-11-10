import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/camera/camera_page.dart';
import 'package:open_matchday/camera/tally.dart';

void main() {
  test('tally on only when Program matches this camera', () {
    const off = CameraTally(cameraSourceId: 'cam-1', programSourceId: '');
    expect(off.isOnAir, isFalse);

    const other = CameraTally(cameraSourceId: 'cam-1', programSourceId: 'cam-2');
    expect(other.isOnAir, isFalse);

    const onAir = CameraTally(cameraSourceId: 'cam-1', programSourceId: 'cam-1');
    expect(onAir.isOnAir, isTrue);
  });

  testWidgets('camera page shows unmistakable ON AIR tally', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CameraPage(
          tally: CameraTally(
            cameraSourceId: 'cam-1',
            programSourceId: 'cam-1',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('camera-tally')), findsOneWidget);
    expect(find.text('ON AIR'), findsOneWidget);
    expect(find.textContaining('Program source: cam-1'), findsOneWidget);
  });

  testWidgets('camera page shows TALLY OFF when not on Program', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CameraPage(
          tally: CameraTally(
            cameraSourceId: 'cam-1',
            programSourceId: 'cam-2',
          ),
        ),
      ),
    );

    expect(find.text('TALLY OFF'), findsOneWidget);
    expect(find.textContaining('other camera'), findsOneWidget);
  });
}

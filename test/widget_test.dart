import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/main.dart';
import 'package:open_matchday/role_shell.dart';
import 'package:open_matchday/roles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('open_matchday/media'),
      (MethodCall call) async {
        return <String, Object>{
          'platform': 'test',
          'stamp': '1',
        };
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

  testWidgets('role shell lists roles and pings media', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(const OpenMatchdayApp());

    expect(find.text('Open Matchday — role shell'), findsOneWidget);
    expect(find.text('No role assigned'), findsOneWidget);
    expect(find.text('Director'), findsWidgets);
    expect(find.text('Program Monitor'), findsWidgets);

    for (final role in allProductionRoles) {
      expect(find.byKey(Key('role-shell-${role.id}')), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(FilterChip, 'Director'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-roles')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Assigned: Director'), findsOneWidget);

    await tester.ensureVisible(find.text('Ping media callback'));
    await tester.tap(find.text('Ping media callback'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Media callback OK: platform=test'),
      findsOneWidget,
    );

    expect(find.text('Open pairing'), findsOneWidget);
  });

  testWidgets('release build blocks unverified combination apply',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RoleShellPage(releaseBuild: true),
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Event Operator'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('combination-gate-status')), findsOneWidget);
    expect(find.textContaining('blocked in release'), findsOneWidget);

    await tester.tap(find.byKey(const Key('apply-roles')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot be enabled in release builds'),
      findsOneWidget,
    );
  });
}

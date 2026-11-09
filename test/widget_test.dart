import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/main.dart';

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
    await tester.pumpWidget(const OpenMatchdayApp());

    expect(find.text('Open Matchday — role shell'), findsOneWidget);
    expect(find.text('No role assigned'), findsOneWidget);
    expect(find.text('Director'), findsOneWidget);
    expect(find.text('Program Monitor'), findsOneWidget);

    await tester.tap(find.text('Director'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Assigned: Director'), findsOneWidget);

    await tester.tap(find.text('Ping media callback'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Media callback OK: platform=test'),
      findsOneWidget,
    );

    expect(find.text('Open pairing'), findsOneWidget);
  });
}
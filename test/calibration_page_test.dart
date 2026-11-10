import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/calibration/calibration_page.dart';
import 'package:open_matchday/calibration/calibration_store.dart';
import 'package:open_matchday/calibration/geometry.dart';

void main() {
  testWidgets('calibration page freezes and confirms geometry', (tester) async {
    final store = CalibrationStore(clockMs: () => 7);
    await tester.pumpWidget(
      MaterialApp(
        home: CalibrationPage(store: store),
      ),
    );

    expect(find.byKey(const Key('calibration-phase')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calibration-freeze')));
    await tester.pump();
    expect(store.phase, CalibrationPhase.frozen);

    store.setAllCorners(
      const CornerSet(
        tl: CalibPoint(230.4, 158.4),
        tr: CalibPoint(1049.6, 129.6),
        br: CalibPoint(1126.4, 561.6),
        bl: CalibPoint(179.2, 518.4),
      ),
    );
    await tester.tap(find.byKey(const Key('calibration-compute')));
    await tester.pump();
    expect(store.phase, CalibrationPhase.rectifiedPending);

    await tester.tap(find.byKey(const Key('calibration-confirm')));
    await tester.pump();
    expect(store.geometryAccepted, isTrue);
    expect(find.byKey(const Key('calibration-fields')), findsOneWidget);
    expect(find.byKey(const Key('region-shot_clock')), findsOneWidget);
  });
}
